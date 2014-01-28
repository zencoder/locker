class Locker
  class LockStolen < StandardError; end

  if !defined?(SecureRandom)
    SecureRandom = ActiveSupport::SecureRandom
  end

  attr_accessor :identifier, :key, :model, :locked, :blocking, :check, :check_every

  class << self
    attr_accessor :model
  end

  def initialize(key, options={})
    @identifier  = "host:#{Socket.gethostname} pid:#{Process.pid} guid:#{SecureRandom.hex(16)}" rescue "pid:#{Process.pid} guid:#{SecureRandom.hex(16)}"
    @key         = key
    @model       = (options[:model] || self.class.model || ::Lock)
    @blocking    = !!options[:blocking]
    @locked      = false
    @lock_id     = find_or_create_lock_record.id
    @check       = options.fetch(:check, true)
    @check_every = (options[:check_every] || 10.seconds).to_f

    if @check
      raise ArgumentError, "check_every must be greater than 0" if @check_every <= 0
    end
  end

  def self.run(key, options={}, &block)
    locker = new(key, options)
    locker.run(&block)
  end

  def run(blocking=@blocking, &block)
    get(blocking)

    if @locked
      if @check
        begin
          parent_thread = Thread.current
          connection    = model.connection

          checker = Thread.new do
            while @locked
              sleep @check_every
              check(parent_thread, connection)
            end
          end

          block.call
        ensure
          checker.exit rescue nil
        end
      else
        block.call
      end

      true
    else
      false
    end
  ensure
    release
  end

  def get(blocking=@blocking)
    @locked = get_advisory_lock(blocking)
  end

  def release
    @locked = false
    release_advisory_lock
  end

  def check(thread=Thread.current, connection=model.connection)
    if connection.active? && holds_advisory_lock?(connection)
      true
    else
      thread.raise LockStolen
      false
    end
  end


private

  def find_or_create_lock_record
    model.find_by_key(@key) || model.create!(:key => @key)
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message =~ /duplicate key value violates unique constraint/
  end

  def get_advisory_lock(blocking)
    success = execute_lock == "t"

    while !success && blocking
      sleep 0.5
      success = execute_lock == "t"
    end

    if success
      update_all(["locked_by = ?, locked_at = clock_timestamp() at time zone 'UTC'", @identifier], ["id = ?", @lock_id])
    end

    success
  end

  def execute_lock
    model.connection.select_value("SELECT pg_try_advisory_lock(#{@lock_id})")
  end

  def release_advisory_lock
    update_all(["locked_by = NULL, locked_at = NULL"], ["id = ? AND locked_by = ?", @lock_id, @identifier])
    execute_release == "t"
  end

  def execute_release
    model.connection.select_value("SELECT pg_advisory_unlock(#{@lock_id})")
  end

  def update_all(*args)
    model.update_all(*args) > 0
  end

  def holds_advisory_lock?(connection)
    "t" == connection.select_value("SELECT 't' FROM pg_locks WHERE locktype = 'advisory' AND pid = pg_backend_pid() AND objid = #{@lock_id}")
  end

end
