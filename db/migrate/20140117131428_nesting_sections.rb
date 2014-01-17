class NestingSections < ActiveRecord::Migration
  def self.up
    add_column :sections, :parent_section_id, :int
  end
  
  def self.down
    remove_column :sections, :parent_section_id
  end
end