class Locker
  class LockStolen < StandardError; end

  if !defined?(SecureRandom)
    SecureRandom = ActiveSupport::SecureRandom
  end

  attr_accessor :identifier, :key, :model, :locked, :blocking

  class << self
    attr_accessor :model
  end

  def initialize(key, options={})
    @identifier = "host:#{Socket.gethostname} pid:#{Process.pid} guid:#{SecureRandom.hex(16)}" rescue "pid:#{Process.pid} guid:#{SecureRandom.hex(16)}"
    @key        = key
    @model      = (options[:model] || self.class.model || ::Lock)
    @blocking   = !!options[:blocking]
    @locked     = false
    @lock_id    = find_or_create_lock_record.id
  end

  def self.run(key, options={}, &block)
    locker = new(key, options)
    locker.run(&block)
  end

  def run(blocking=@blocking, &block)
    get(blocking)

    if @locked
      block.call
    end

    @locked
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


private

  def find_or_create_lock_record
    model.find_by_key(@key) || model.create!(:key => @key)
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message =~ /duplicate key value violates unique constraint/
  end

  def get_advisory_lock(blocking)
    success = model.connection.select_value("SELECT pg_#{blocking ? "" : "try_"}advisory_lock(#{@lock_id})") == "t"

    if success
      update_all(["locked_by = ?, locked_at = clock_timestamp() at time zone 'UTC'", @identifier], ["id = ?", @lock_id])
    end

    success
  end

  def release_advisory_lock
    update_all(["locked_by = NULL, locked_at = NULL"], ["id = ? AND locked_by = ?", @lock_id, @identifier])
    model.connection.select_value("SELECT pg_advisory_unlock(#{@lock_id})") == "t"
  end

  def update_all(*args)
    model.update_all(*args) > 0
  end

end
