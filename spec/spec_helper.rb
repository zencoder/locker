$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'
require 'bundler/setup'
require 'active_record'

require 'locker'

ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.default_timezone = "UTC"

config = YAML.load_file(File.join(File.dirname(__FILE__), 'database.yml'))
begin
  ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
  ActiveRecord::Base.connection.create_database(config['database'], config.merge("encoding" => config['encoding'] || ENV['CHARSET'] || 'utf8'))
rescue ActiveRecord::StatementInvalid => e
  raise unless e.message =~ /database "locker_test" already exists/
end

ActiveRecord::Base.establish_connection(config)

ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS locks")
ActiveRecord::Base.connection.create_table(:locks) do |t|
  t.string :locked_by
  t.string :key
  t.integer :sequence, :default => 0
  t.datetime :locked_at
  t.datetime :locked_until
end
ActiveRecord::Base.connection.add_index :locks, :key, :unique => true

class Lock < ActiveRecord::Base
end

class FakeLock
  attr_accessor :locked_by, :key, :locked_at, :locked_until

  cattr_accessor :fake_locks
  self.fake_locks = {}

  def self.find_by_key(key)
    fake_locks[key]
  end

  def self.find_by_key_and_locked_by(key, locked_by)
    lock = fake_locks[key]

    if lock && lock.locked_by == locked_by
      lock
    end
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
