class LockerGenerator < Rails::Generator::Base
  attr_reader :name

  def initialize(runtime_args, runtime_options={})
    super
    @name = (runtime_args.first || "lock").underscore
  end

  def manifest
    record do |m|
      m.directory "app/models"
      m.template "model.rb", "app/models/#{name}.rb"
      m.migration_template "migration.rb", "db/migrate", :migration_file_name => "create_#{plural_name}"
    end
  end

  def plural_name
    name.pluralize
  end

  def plural_class_name
    plural_name.camelize
  end

  def class_name
    name.camelize
  end
end
