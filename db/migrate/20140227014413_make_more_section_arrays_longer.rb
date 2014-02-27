class MakeMoreSectionArraysLonger < ActiveRecord::Migration
  def self.up
    change_column :sections, :ayes, :string, :limit => 1000, :array => true
    change_column :sections, :noes, :string, :limit => 1000, :array => true
  end
  
  def self.down
    change_column :sections, :ayes, :string, :limit => 255, :array => true
    change_column :sections, :noes, :string, :limit => 255, :array => true
  end
end