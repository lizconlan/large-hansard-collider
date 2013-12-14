class RemoveParagraphHtml < ActiveRecord::Migration
  def self.up
    remove_column :paragraphs, :html
  end
  
  def self.down
    add_column :paragraphs, :html, :text
  end
end