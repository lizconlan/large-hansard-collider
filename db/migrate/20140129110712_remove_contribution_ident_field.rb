class RemoveContributionIdentField < ActiveRecord::Migration
  def self.up
    remove_column :paragraphs, :contribution_ident
  end
  
  def self.down
    add_column :paragraphs, :contribution_ident, :string
  end
end