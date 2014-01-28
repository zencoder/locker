require "spec_helper"

describe Locker::ExplicitAdvisoryLock do
  Locker::ExplicitAdvisoryLock.model = ::Lock

  describe "initialization" do
    it "should have default values" do
      locker = Locker::ExplicitAdvisoryLock.new(123)
      locker.lock_id.should == 123
      locker.check_every.should == 10
      locker.blocking.should be_false
      locker.check.should be_true
      locker.should_not be_locked
    end

    it "should have some overridable values" do
      locker = Locker::ExplicitAdvisoryLock.new(123, :check_every => 60, :blocking => true, :check => false)
      locker.lock_id.should == 123
      locker.check_every.should == 60
      locker.blocking.should be_true
      locker.check.should be_false
      locker.should_not be_locked
    end

    it "should validate renew_every and lock_for values" do
      expect{ Locker::ExplicitAdvisoryLock.new("foo") }.to raise_error(ArgumentError)
      expect{ Locker::ExplicitAdvisoryLock.new(123, :check_every => 0) }.to raise_error(ArgumentError)
      expect{ Locker::ExplicitAdvisoryLock.new(123, :check_every => 1) }.to_not raise_error
    end
  end

  describe "locking" do
    let(:locker){ Locker::ExplicitAdvisoryLock.new(123, :check_every => 0.1) }

    after do
      locker.release if locker.locked?
    end

    it "should lock" do
      locker.get.should be_true
      locker.should be_locked
    end

    it "should release locks" do
      locker.get.should be_true
      locker.should be_locked
      locker.release.should be_true
      locker.should_not be_locked
    end

    it "should raise a LockStolen exception when the lock is stolen" do
      expect {
        locker.run do
          locker.send(:execute_release)
          sleep 0.3
        end
      }.to raise_error(Locker::LockStolen)
    end
  end

  # describe "blocking" do
  #   before do
  #     @first_locker = Locker.new("foo", :renew_every => 0.2.second, :lock_for => 0.6.second)
  #     @second_locker = Locker.new("foo")
  #     @first_locker.get
  #   end
  # 
  #   it "should block and wait for the first lock to release before running the second" do
  #     start_time = Time.now.to_f
  #     @second_locker.run(true){"something innocuous"}
  #     end_time = Time.now.to_f
  #     time_ran = (end_time - start_time)
  #     time_ran.should be >= 0.6, "Oops, time was #{end_time-start_time} seconds"
  #   end
  # end
  # 
  # describe "non-blocking" do
  #   before do
  #     @first_locker = Locker.new("foo")
  #     @second_locker = Locker.new("foo")
  #     @first_locker.get
  #   end
  # 
  #   it "should return false when we can't obtain the lock" do
  #     @second_locker.run{raise "SHOULD NOT RUN KTHXBAI"}.should be_false
  #     @first_locker.run{ "something" }.should be_true
  #   end
  # 
  #   it "should take less than half a second to fail" do
  #     start_time = Time.now.to_f
  #     return_value = @second_locker.run{raise "SHOULD NOT RUN KTHXBAI"}
  #     end_time = Time.now.to_f
  #     return_value.should be_false
  #     run_time = (end_time - start_time)
  #     run_time.should be < 0.5
  #   end
  # end

end
