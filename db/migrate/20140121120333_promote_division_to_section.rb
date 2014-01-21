class PromoteDivisionToSection < ActiveRecord::Migration
  def self.up
    add_column :sections, :division_number, :string
    add_column :sections, :tellers_ayes, :string, :array => true
    add_column :sections, :tellers_noes, :string, :array => true
    add_column :sections, :ayes, :string, :array => true
    add_column :sections, :noes, :string, :array => true
    
    remove_column :paragraphs, :number
    remove_column :paragraphs, :tellers_ayes
    remove_column :paragraphs, :tellers_noes
    remove_column :paragraphs, :ayes
    remove_column :paragraphs, :noes
    remove_column :paragraphs, :timestamp
    remove_column :paragraphs, :description
  end
  
  def self.down
    add_column :paragraphs, :number, :string
    add_column :paragraphs, :tellers_ayes, :string
    add_column :paragraphs, :tellers_noes, :string
    add_column :paragraphs, :ayes, :string, :array => true
    add_column :paragraphs, :noes, :string, :array => true
    add_column :paragraphs, :timestamp, :string
    add_column :paragraphs, :description, :string
    
    remove_column :sections, :division_number
    remove_column :sections, :tellers_ayes
    remove_column :sections, :tellers_noes
    remove_column :sections, :ayes
    remove_column :sections, :noes
  end
end