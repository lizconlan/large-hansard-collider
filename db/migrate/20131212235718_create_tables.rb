class CreateTables < ActiveRecord::Migration
  def self.up
    create_table :daily_parts do |t|
      t.date    :date
      t.string  :ident
      t.string  :volume
      t.string  :part
      t.string  :house
    end
    
    add_index(:daily_parts, :ident)
    
    create_table :components do |t|
      t.integer :daily_part_id
      t.string  :ident
      t.string  :name
      t.integer :sequence
      t.string  :url
    end
    
    add_index(:components, :ident)
    
    create_table :fragments do |t|
      t.integer :component_id
      t.string  :ident
      t.string  :title
      t.string  :url
      t.integer :sequence
      t.string  :members, :array => true
      t.string  :columns, :array => true
      t.string  :chair
      t.string  :department
      t.string  :subject
      t.string  :number
      t.string  :asked_by
      t.string  :question_type
    end
    
    add_index(:fragments, :ident)
    
    create_table :paragraphs do |t|
      t.integer :fragment_id
      t.string  :ident
      t.string  :url
      t.string  :column
      t.text    :text
      t.text    :html
      t.integer :sequence
      t.string  :member
      t.string  :speaker_printed_name
      t.string  :contribution_ident
      t.string  :description
      t.string  :number
      t.string  :tellers_ayes
      t.string  :tellers_noes
      t.string  :ayes, :array => true
      t.string  :noes, :array => true
      t.string  :timestamp
    end
    
    add_index(:paragraphs, :ident)
  end
  
  def self.down
    drop_table :paragraphs
    drop_table :fragments
    drop_table :components
    drop_table :daily_parts
  end
end