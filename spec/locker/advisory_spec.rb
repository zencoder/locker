require "spec_helper"

describe Locker::Advisory do

  describe "initialization" do
    it "should have default values" do
      advisory = Locker::Advisory.new("foo")
      advisory.key.should == "foo"
      advisory.crc.should == -1938594527
      advisory.lockspace.should == 1
      advisory.blocking.should be_false
      advisory.locked.should be_false
    end

    it "should have some overridable values" do
      advisory = Locker::Advisory.new("foo", :lockspace => 2, :blocking => true)
      advisory.lockspace.should == 2
      advisory.blocking.should be_true
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

      t = Thread.new do
        Locker::Advisory.run("foo") do
          lock1 = true
          sleep 1
        end
      end

      Thread.pass

      lock2_result = Locker::Advisory.run("foo") do
        lock2 = true
      end

      lock1_result = t.join
      lock1.should be_true
      lock2.should be_false
      lock1_result.should be_true
      lock2_result.should be_false
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

      lock1.should be_true
      lock2.should be_true
      lock1_result.should be_true
      lock2_result.should be_true
    end
  end

end
