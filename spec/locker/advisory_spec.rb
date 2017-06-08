require "spec_helper"

describe Locker::Advisory do

  describe "initialization" do
    it "should have default values" do
      advisory = Locker::Advisory.new("foo")
      expect(advisory.key).to eq("foo")
      expect(advisory.crc).to eq(-1938594527)
      expect(advisory.lockspace).to eq(1)
      expect(advisory.blocking).to be false
      expect(advisory.locked).to be false
    end

    it "should have some overridable values" do
      advisory = Locker::Advisory.new("foo", :lockspace => 2, :blocking => true)
      expect(advisory.lockspace).to eq(2)
      expect(advisory.blocking).to be true
    end

    it "should validate key" do
      expect{ Locker::Advisory.new(1) }.to raise_error(ArgumentError)
    end

    it "should validate lockspace" do
      expect{ Locker::Advisory.new("foo", :lockspace => Locker::Advisory::MIN_LOCK - 1) }.to raise_error(ArgumentError)
      expect{ Locker::Advisory.new("foo", :lockspace => Locker::Advisory::MAX_LOCK + 1) }.to raise_error(ArgumentError)
    end
  end

  describe "locking" do
    it "should lock to the exclusion of other locks and return true on success and false on failure" do
      lock1 = false
      lock2 = false

      t1 = Thread.new do
        Locker::Advisory.run("foo") do
          lock1 = true
          sleep 2
        end
      end

      t2 = Thread.new do
        sleep 1
        Locker::Advisory.run("foo") do
          lock2 = true
        end
      end

      lock1_result = t1.value
      lock2_result = t2.value
      expect(lock1).to be true
      expect(lock2).to be false
      expect(lock1_result).to be true
      expect(lock2_result).to be false
    end

    it "should release locks after the block is finished" do
      lock1 = false
      lock2 = false

      lock1_result = Locker::Advisory.run("foo") do
        lock1 = true
      end

      lock2_result = Locker::Advisory.run("foo") do
        lock2 = true
      end

      expect(lock1).to be true
      expect(lock2).to be true
      expect(lock1_result).to be true
      expect(lock2_result).to be true
    end

    it "blocks with a timeout" do
      started_at = Time.now
      t1 = Thread.new do
        Locker::Advisory.run("foo") do
          sleep 2
        end
      end

      t2 = Thread.new do
        sleep 0.5
        Locker::Advisory.run("foo", :blocking => true, :block_timeout => 1) do
          sleep 10 # never hits this
        end
      end

      expect(t1.value).to be(true)
      expect(t2.value).to be(false)

      expect(Time.now - started_at).to be < 2.5
    end
  end

end
