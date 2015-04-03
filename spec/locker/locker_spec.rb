require "spec_helper"

describe Locker do
  before do
    Lock.delete_all
    FakeLock.fake_locks = {}
  end

  describe "initialization" do
    it "should have default values" do
      locker = Locker.new("foo")
      expect(locker.key).to eq("foo")
      expect(locker.renew_every).to eq(10)
      expect(locker.lock_for).to eq(30)
      expect(locker.model).to eq(Lock)
      expect(locker.identifier).to match(/^#{Regexp.escape("host:#{Socket.gethostname} pid:#{Process.pid}")} guid:[a-f0-9]+$/)
      expect(locker.blocking).to be false
      expect(locker.locked).to be false
    end

    it "should have some overridable values" do
      locker = Locker.new("bar", :renew_every => 20.seconds, :lock_for => 1.minute, :blocking => true, :model => FakeLock)
      expect(locker.key).to eq("bar")
      expect(locker.renew_every).to eq(20)
      expect(locker.lock_for).to eq(60)
      expect(locker.model).to eq(FakeLock)
      expect(locker.identifier).to match(/^#{Regexp.escape("host:#{Socket.gethostname} pid:#{Process.pid}")} guid:[a-f0-9]+$/)
      expect(locker.blocking).to be true
      expect(locker.locked).to be false
    end

    it "should ensure that the key exists" do
      expect(Lock.find_by_key("baz")).to be_nil
      Locker.new("baz", :renew_every => 20.seconds, :lock_for => 1.minute, :blocking => true)
      expect(Lock.find_by_key("baz")).to_not be_nil
      Locker.new("baz", :renew_every => 20.seconds, :lock_for => 1.minute, :blocking => true)
    end

    it "should validate renew_every and lock_for values" do
      expect{ Locker.new("foo", :renew_every => 0) }.to raise_error(ArgumentError)
      expect{ Locker.new("foo", :renew_every => 1) }.to_not raise_error
      expect{ Locker.new("foo", :lock_for => 0) }.to raise_error(ArgumentError)
      expect{ Locker.new("foo", :renew_every => 4, :lock_for => 2) }.to raise_error(ArgumentError)
      expect{ Locker.new("foo", :renew_every => 1, :lock_for => 1.00001) }.to_not raise_error
    end
  end

  describe "locking" do
    it "should lock a record" do
      locker = Locker.new("foo")
      expect(locker.get).to be true

      lock = Lock.find_by_key("foo")
      expect(lock.locked_until).to be <= (Time.now.utc + locker.lock_for)
      expect(lock.locked_by).to eq(locker.identifier)
      expect(lock.locked_at).to be < Time.now.utc
    end

    it "should renew a lock" do
      locker = Locker.new("foo")
      expect(locker.get).to be true
      lock = Lock.find_by_key("foo")
      expect(lock.locked_until).to be <= (Time.now.utc + locker.lock_for)
      expect(lock.locked_by).to eq(locker.identifier)
      expect(lock.locked_at).to be < Time.now.utc
      expect(locker.renew).to be true
      lock = Lock.find_by_key("foo")
      expect(lock.locked_until).to be <= (Time.now.utc + locker.lock_for)
      expect(lock.locked_by).to eq(locker.identifier)
      expect(lock.locked_at).to be < Time.now.utc
    end

    it "should raise when someone steals the lock" do
      locker = Locker.new("foo")
      expect(locker.get).to be true
      lock = Lock.find_by_key("foo")
      lock.update_attribute(:locked_by, "someone else")
      expect{ locker.renew }.to raise_error(Locker::LockStolen)
    end

    it "should raise to the parent thread when the renewer is in a thread and someone steals the lock" do
      expect do
        Locker.run("steal me", :renew_every => (0.1).seconds) do
          Lock.find_by_key("steal me").update_attribute(:locked_by, "contrived example")
          sleep(0.3)
        end
      end.to raise_error(Locker::LockStolen)
    end

    it "should call the passed in block when the lock is aquired" do
      value = nil
      Locker.run("foo") do
        value = 1
      end
      expect(value).to eq(1)
    end

    it "should pass in a sequence number representing the number of times the lock has been locked" do
      (1..10).each do |i|
        value = nil
        Locker.run("foo") do |sequence|
          value = sequence
        end
        expect(value).to eq(i)
      end
    end
  end

  describe "blocking" do
    before do
      @first_locker = Locker.new("foo", :renew_every => 0.2.second, :lock_for => 0.6.second)
      @second_locker = Locker.new("foo")
      @first_locker.get
    end

    it "should block and wait for the first lock to release before running the second" do
      start_time = Time.now.to_f
      @second_locker.run(true){"something innocuous"}
      end_time = Time.now.to_f
      time_ran = (end_time - start_time)
      expect(time_ran).to be >= 0.6, "Oops, time was #{end_time-start_time} seconds"
    end
  end

  describe "non-blocking" do
    before do
      @first_locker = Locker.new("foo")
      @second_locker = Locker.new("foo")
      @first_locker.get
    end

    it "should return false when we can't obtain the lock" do
      expect(@second_locker.run{raise "SHOULD NOT RUN KTHXBAI"}).to be false
      expect(@first_locker.run{ "something" }).to be true
    end

    it "should take less than half a second to fail" do
      start_time = Time.now.to_f
      return_value = @second_locker.run{raise "SHOULD NOT RUN KTHXBAI"}
      end_time = Time.now.to_f
      expect(return_value).to be false
      run_time = (end_time - start_time)
      expect(run_time).to be < 0.5
    end
  end

end
