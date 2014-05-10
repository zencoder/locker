require "zlib"

class Locker
  class Advisory
    class LockConnectionLost < StandardError; end

    attr_reader :key, :crc, :lockspace, :blocking, :locked

    MAX_LOCK = 2147483647
    MIN_LOCK = -2147483648
    OVERFLOW_ADJUSTMENT = 2**32

    def initialize(key, options={})
      raise ArgumentError, "key must be a string" unless key.is_a?(String)

      @key       = key
      @crc       = convert_to_crc(key)
      @lockspace = (options[:lockspace] || 1)
      @blocking  = !!options[:blocking]
      @locked    = false

      if !@lockspace.is_a?(Integer) || @lockspace < MIN_LOCK || @lockspace > MAX_LOCK
        raise ArgumentError, "The :lockspace option must be an integer between #{MIN_LOCK} and #{MAX_LOCK}"
      end
    end

    def self.run(key, options={}, &block)
      advisory = new(key, options)
      advisory.run(&block)
    end

    def run(&block)
      connection = ActiveRecord::Base.connection_pool.checkout
      connection.transaction :requires_new => true do
        ensure_unlocked(connection)

        while !get(connection) && @blocking
          sleep 0.5
        end

        if @locked
          begin
            parent_thread = Thread.current

            mutex = Mutex.new

            checker = Thread.new do
              while @locked
                10.times{ sleep 0.5 if @locked }
                mutex.synchronize do
                  if @locked
                    check(connection, parent_thread)
                  end
                end
              end
            end

            block.call
          ensure
            release(connection) if @locked
            # Using a mutex to synchronize so that we're sure we're not
            # executing a query when we kill the thread.
            mutex.synchronize{}
            if checker.alive?
              checker.exit rescue nil
            end
          end
          true
        else
          false
        end
      end
    ensure
      ActiveRecord::Base.connection_pool.checkin(connection) if connection
    end

  protected

    def get(connection)
      result = exec_query(connection, "SELECT pg_try_advisory_xact_lock(#{connection.quote(@lockspace)}, #{connection.quote(@crc)})")
      @locked = successful_result?(result)
    end

    def release(connection)
      result = exec_query(connection, "SELECT pg_advisory_unlock(#{connection.quote(@lockspace)}, #{connection.quote(@crc)})")
      successful_result?(result)
    end

    def ensure_unlocked(connection)
      while release(connection); end
    end

    def check(connection, thread)
      if !connection.active?
        @locked = false
        thread.raise LockConnectionLost
      end
    end

    def convert_to_crc(key)
      crc = Zlib.crc32(key)
      crc -= OVERFLOW_ADJUSTMENT if crc > MAX_LOCK
      crc
    end

    def successful_result?(result)
      result.rows.size == 1 && result.rows[0].size == 1 && result.rows[0][0] == "t"
    end

    def exec_query(connection, query)
      silence_stderr do
        connection.exec_query(query, "Locker::Advisory")
      end
    end

  end
end
