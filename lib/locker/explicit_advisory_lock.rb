require "locker"

class Locker
  class ExplicitAdvisoryLock
    attr_accessor :lock_id, :blocking, :check, :check_every

    class << self
      attr_accessor :model
    end

    def initialize(pg_advisory_lock_id, options={})
      @lock_id     = pg_advisory_lock_id
      @blocking    = !!options[:blocking]
      @check       = options.fetch(:check, true)
      @check_every = (options[:check_every] || 10.seconds).to_f

      if !@lock_id.is_a?(Integer)
        raise ArgumentError, "pg_advisory_lock_id must be an integer"
      end

      if @check
        raise ArgumentError, "check_every must be greater than 0" if @check_every <= 0
      end
    end

    def self.run(pg_advisory_lock_id, options={}, &block)
      locker = new(pg_advisory_lock_id, options)
      locker.run(&block)
    end

    def run(blocking=@blocking, &block)
      locked = get(blocking)

      if locked
        if @check
          begin
            parent_thread = Thread.current
            connection    = self.class.model.connection

            checker = Thread.new do
              while check_lock(parent_thread, connection)
                sleep @check_every
              end
            end

            block.call
          ensure
            checker.exit rescue nil
            release
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
      success = execute_lock == "t"

      while !success && blocking
        sleep 0.5
        success = execute_lock == "t"
      end

      success
    end

    def release
      execute_release == "t"
    end

    def locked?(connection=self.class.model.connection)
      connection.active? && execute_check_advisory_lock(connection) == "t"
    end

    def check_lock(thread=Thread.current, connection=self.class.model.connection)
      if locked?(connection)
        true
      else
        thread.raise LockStolen
        false
      end
    end


  private

    def execute_lock(connection=self.class.model.connection)
      connection.select_value("SELECT pg_try_advisory_lock(#{@lock_id})")
    end

    def execute_release(connection=self.class.model.connection)
      connection.select_value("SELECT pg_advisory_unlock(#{@lock_id})")
    end

    def execute_check_advisory_lock(connection=self.class.model.connection)
      connection.select_value("SELECT 't' FROM pg_locks WHERE locktype = 'advisory' AND pid = pg_backend_pid() AND objid = #{@lock_id}")
    end

  end
end
