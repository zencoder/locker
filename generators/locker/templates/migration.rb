class Create<%= plural_class_name %> < ActiveRecord::Migration
  def self.up
    create_table :<%= plural_name %> do |t|
      t.string :locked_by
      t.string :key
      t.datetime :locked_at
      t.datetime :locked_until
    end

    add_index :<%= plural_name %>, :key, :unique => true
  end

  def self.down
    drop_table :<%= plural_name %>
  end
end
