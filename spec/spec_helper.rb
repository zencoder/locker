$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'
require 'bundler/setup'
require 'active_record'

require 'locker'

require 'db_setup'

class FakeLock
  attr_accessor :locked_by, :key, :locked_at, :locked_until

  cattr_accessor :fake_locks
  self.fake_locks = {}

  def self.find_by_key(key)
    fake_locks[key]
  end

  def self.create(attributes={})
    fake_locks[attributes[:key]] = new(attributes)
    true
  end

  def initialize(attributes={})
    attributes.each do |key, value|
      send("#{key}=", value)
    end
  end
end

RSpec.configure do |c|
  c.before do
    ActiveRecord::Base.connection.increment_open_transactions
    ActiveRecord::Base.connection.begin_db_transaction
  end
  c.after do
    ActiveRecord::Base.connection.rollback_db_transaction
    ActiveRecord::Base.connection.decrement_open_transactions
  end
end
