require "zlib"

class Locker
  class Advisory
    class LockConnectionLost < StandardError; end

    attr_reader :key, :crc, :lockspace, :blocking, :locked

    # The advisory function we use from PostgreSQL needs the arguments to be
    # INT, therefore this are the range of int numbers for PostgreSQL
    MAX_LOCK = 2147483647
    MIN_LOCK = -2147483648

    # Max number that a 32bit computer can hold
    OVERFLOW_ADJUSTMENT = 2**32

    def initialize(key, options={})
      raise ArgumentError, "key must be a string" unless key.is_a?(String)

      @key             = key
      @crc             = convert_to_crc(key)
      @lockspace       = (options[:lockspace] || 1)
      @blocking        = !!options[:blocking]
      @locked          = false
      @block_timeout   = options[:block_timeout]
      @block_spin_wait = options[:block_spin_wait] || 0.005

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
        if @blocking && @block_timeout
          break_at = Time.now + @block_timeout
        end

        while !get(connection) && @blocking
          break if break_at && break_at < Time.now
          sleep @block_spin_wait
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
            @locked = false
            # Using a mutex to synchronize so that we're sure we're not
            # executing a query when we kill the thread.
            mutex.synchronize do
              if checker.alive?
                checker.exit rescue nil
              end
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
      lockspace_quote = connection.quote(@lockspace)
      crc_quote = connection.quote(@crc)

      result = exec_query(
        connection,
        "SELECT pg_try_advisory_xact_lock(#{lockspace_quote}, #{crc_quote})"
      )
      @locked = successful_result?(result)
    end

    def check(connection, thread)
      if !connection.active?
        @locked = false
        thread.raise LockConnectionLost
      end
    end

    # CRC32 digest to get a decimal numeric of the key used, make sure the
    # resulting number is within PostgreSql max and min Integer numbers
    def convert_to_crc(key)
      crc = Zlib.crc32(key)
      crc -= OVERFLOW_ADJUSTMENT if crc > MAX_LOCK
      crc
    end

    def successful_result?(result)
      result.rows.size == 1 &&
        result.rows[0].size == 1 && (
          result.rows[0][0] == 't' || # Checking for old ActiveRecord
          result.rows[0][0].class == TrueClass # Checking for the value true
        )
    end

    def exec_query(connection, query)
      connection.exec_query(query, "Locker::Advisory")
    end

  end
end
