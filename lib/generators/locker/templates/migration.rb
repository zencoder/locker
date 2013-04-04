class Create<%= plural_name.camelize %> < ActiveRecord::Migration
  <%- if ActiveRecord::VERSION::MAJOR > 3 || ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR >= 1 -%>
  def change
    create_table :<%= plural_name %> do |t|
      t.string :locked_by
      t.string :key
      t.integer :sequence, :default => 0, :limit => 8
      t.datetime :locked_at
      t.datetime :locked_until
    end

    add_index :<%= plural_name %>, :key, :unique => true
  end
  <%- else -%>
  def self.up
    create_table :<%= plural_name %> do |t|
      t.string :locked_by
      t.string :key
      t.integer :sequence, :default => 0, :limit => 8
      t.datetime :locked_at
      t.datetime :locked_until
    end

    add_index :<%= plural_name %>, :key, :unique => true
  end

  def self.down
    drop_table :<%= plural_name %>
  end
  <%- end -%>
end
