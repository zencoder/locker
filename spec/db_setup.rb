require 'active_record'

ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.default_timezone = "UTC"

config = YAML.load_file(File.join(File.dirname(__FILE__), 'database.yml'))["test"]
begin
  ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
  ActiveRecord::Base.connection.create_database(config['database'], config.merge("encoding" => config['encoding'] || ENV['CHARSET'] || 'utf8'))
rescue ActiveRecord::StatementInvalid => e
  raise unless e.message =~ /database "locker_test" already exists/
end

ActiveRecord::Base.establish_connection(config)

begin
  ActiveRecord::Base.connection.create_table(:locks) do |t|
    t.string :locked_by
    t.string :key
    t.datetime :locked_at
    t.datetime :locked_until
  end
  ActiveRecord::Base.connection.add_index :locks, :key, :unique => true
rescue ActiveRecord::StatementInvalid => e
  raise unless e.message =~ /relation "locks" already exists/
end

class Lock < ActiveRecord::Base
end
