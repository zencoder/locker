class Locker
  class LockStolen < StandardError; end

  attr_accessor :key, :check, :check_every, :model, :locked, :blocking

  class << self
    attr_accessor :model
  end

  def initialize(key, options={})
    @key         = key
    @check       = options.fetch(:check, true)
    @check_every = (options[:check_every] || 10.seconds).to_f
    @model       = (options[:model] || self.class.model || ::Lock)
    @blocking    = !!options[:blocking]
    @locked      = false

    raise ArgumentError, "check_every must be greater than 0" if @check && @check_every <= 0

    ensure_key_exists
  end

  def self.run(key, options={}, &block)
    locker = new(key, options)
    locker.run(&block)
  end

  def run(blocking=@blocking, &block)
    get(blocking)

    if @locked
      begin
        if @check
          parent_thread = Thread.current
          connection    = @model.connection

          checker = Thread.new do
            while @locked
              sleep @check_every
              check(parent_thread, connection)
            end
          end
        end

        block.call
      ensure
        if @check
          checker.exit rescue nil
        end
      end
    end

    @locked
  ensure
    release
  end

  def get(blocking=true)
    lock_with = blocking ? "FOR UPDATE" : "FOR UPDATE NOWAIT"
    @model.connection.begin_db_transaction
    @model.find_by_key(@key).lock!(lock_with)
    @locked = true
  rescue ActiveRecord::StatementInvalid => e
    if e.message !~ /could not obtain lock on row/
      release
      raise
    end

    false
  end

  def release
    @locked = false
    @model.connection.rollback_db_transaction unless @model.connection.outside_transaction?
  end

  def check(options={})
    if @check
      thread     = options[:thread]     || Thread.current
      connection = options[:connection] || @model.connection

      if !connection.active? || connection.outside_transaction?
        thread.raise LockStolen if @locked
      end

      @locked
    else
      true
    end
  end


private

  def ensure_key_exists
    model.find_by_key(@key) || model.create(:key => @key)
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message =~ /duplicate key value violates unique constraint/
  end

end
