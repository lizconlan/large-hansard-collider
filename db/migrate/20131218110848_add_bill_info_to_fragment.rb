class AddBillInfoToFragment < ActiveRecord::Migration
  def self.up
    add_column :fragments, :bill_title, :string
    add_column :fragments, :bill_stage, :string
  end
  
  def self.down
    remove_column :fragments, :bill_title
    remove_column :fragments, :bill_stage
  end
end