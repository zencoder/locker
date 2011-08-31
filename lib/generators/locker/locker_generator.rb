class LockerGenerator < Rails::Generators::NamedBase
  include Rails::Generators::Migration

  source_root File.expand_path('../templates', __FILE__)
  argument :name, :type => :string, :default => "Lock"

  def self.next_migration_number(path)
    Time.now.utc.strftime("%Y%m%d%H%M%S")
  end

  def create_locker_files
    migration_template "migration.rb", "db/migrate/create_#{plural_name}.rb"
    template "model.rb", "app/models/#{singular_name}.rb"
  end

end
