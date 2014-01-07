class RenameFragmentToSection < ActiveRecord::Migration
  def self.up
    rename_table :fragments, :sections
    rename_column :paragraphs, :fragment_id, :section_id
  end
  
  def self.down
    rename_column :paragraphs, :section_id, :fragment_id
    rename_table :sections, :fragments
  end
end