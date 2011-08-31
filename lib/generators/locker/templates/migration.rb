class Create<%= plural_name.camelize %> < ActiveRecord::Migration
  def change
    create_table :<%= plural_name %> do |t|
      t.string :locked_by
      t.string :key
      t.datetime :locked_at
      t.datetime :locked_until
    end

    add_index :<%= plural_name %>, :key, :unique => true
  end
end
