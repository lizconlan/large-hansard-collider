class MakeChairAnArray < ActiveRecord::Migration
  def self.up
    remove_column :sections, :chair
    add_column :sections, :chair, :string, :array => true
  end
  
  def self.down
    remove_column :sections, :chair
    add_column :sections, :chair, :string
  end
end