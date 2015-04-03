require "socket"
require "securerandom"

class Locker
  class LockStolen < StandardError; end

  attr_accessor :identifier, :key, :renew_every, :lock_for, :model, :locked, :blocking

  class << self
    attr_accessor :model
  end

  def initialize(key, options={})
    @identifier  = "host:#{Socket.gethostname} pid:#{Process.pid} guid:#{SecureRandom.hex(16)}" rescue "pid:#{Process.pid} guid:#{SecureRandom.hex(16)}"
    @key         = key
    @renew_every = (options[:renew_every] || 10.seconds).to_f
    @lock_for    = (options[:lock_for] || 30.seconds).to_f
    @model       = (options[:model] || self.class.model || ::Lock)
    @blocking    = !!options[:blocking]
    @locked      = false

    raise ArgumentError, "renew_every must be greater than 0" if @renew_every <= 0
    raise ArgumentError, "lock_for must be greater than 0" if @lock_for <= 0
    raise ArgumentError, "renew_every must be less than lock_for" if @renew_every >= @lock_for

    ensure_key_exists
  end

  def self.run(key, options={}, &block)
    locker = new(key, options)
    locker.run(&block)
  end

  def run(blocking=@blocking, &block)
    while !get && blocking
      sleep 0.5
    end

    if @locked
      begin
        parent_thread = Thread.current

        renewer = Thread.new do
          while @locked
            sleep @renew_every
            renew(parent_thread)
          end
        end

        block.call(sequence)
      ensure
        renewer.exit rescue nil
        release if @locked
      end

      true
    else
      false
    end
  end

  def get
    @locked = updated?(model.
                       where(["key = ? AND (locked_by IS NULL OR locked_by = ? OR locked_until < clock_timestamp() at time zone 'UTC')", @key, @identifier]).
                       update_all(["locked_by = ?, locked_at = clock_timestamp() at time zone 'UTC', locked_until = clock_timestamp() at time zone 'UTC' + #{lock_interval}, sequence = sequence + 1", @identifier]))
  end

  def release
    @locked = updated?(model.
                       where(["key = ? and locked_by = ?", @key, @identifier]).
                       update_all(["locked_by = NULL"]))
  end

  def renew(thread=Thread.current)
    @locked = updated?(model.
                      where(["key = ? and locked_by = ?", @key, @identifier]).
                      update_all(["locked_until = clock_timestamp() at time zone 'UTC' + #{lock_interval}"]))
    thread.raise LockStolen unless @locked
    @locked
  end

  def sequence
    if @sequence
      @sequence
    else
      record = model.find_by_key_and_locked_by(@key, @identifier)
      @sequence = record && record.sequence
    end
  end

private

  def lock_interval
    "interval '#{@lock_for} seconds'"
  end

  def ensure_key_exists
    model.find_by_key(@key) || model.create(:key => @key)
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message =~ /duplicate key value violates unique constraint/
  end

  # Returns a boolean. True if it updates any rows, false if it didn't.
  def updated?(rows_updated)
    rows_updated > 0
  end

end
