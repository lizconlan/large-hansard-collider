class AddIndexedFlagToSection < ActiveRecord::Migration
  def self.up
    add_column :sections, :indexed, :boolean, :default => false
  end
  
  def self.down
    remove_column :sections, :indexed
  end
end