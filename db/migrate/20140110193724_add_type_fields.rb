class AddTypeFields < ActiveRecord::Migration
  def self.up
    add_column :sections, :type, :string
    add_column :paragraphs, :type, :string
  end
  
  def self.down
    remove_column :sections, :type
    remove_column :sections, :type
  end
end