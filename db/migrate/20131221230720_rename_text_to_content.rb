class RenameTextToContent < ActiveRecord::Migration
  def self.up
    rename_column :paragraphs, :text, :content
  end
  
  def self.down
    rename_column :paragraphs, :content, :text
  end
end