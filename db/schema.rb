# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140129110712) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "components", force: true do |t|
    t.integer "daily_part_id"
    t.string  "ident"
    t.string  "name"
    t.integer "sequence"
    t.string  "url"
  end

  add_index "components", ["ident"], name: "index_components_on_ident", using: :btree

  create_table "daily_parts", force: true do |t|
    t.date   "date"
    t.string "ident"
    t.string "volume"
    t.string "part"
    t.string "house"
  end

  add_index "daily_parts", ["ident"], name: "index_daily_parts_on_ident", using: :btree

  create_table "paragraphs", force: true do |t|
    t.integer "section_id"
    t.string  "ident"
    t.string  "url"
    t.string  "column"
    t.text    "content"
    t.integer "sequence"
    t.string  "member"
    t.string  "speaker_printed_name"
    t.string  "type"
  end

  add_index "paragraphs", ["ident"], name: "index_paragraphs_on_ident", using: :btree

  create_table "sections", force: true do |t|
    t.integer "component_id"
    t.string  "ident"
    t.string  "title"
    t.string  "url"
    t.integer "sequence"
    t.string  "members",           array: true
    t.string  "columns",           array: true
    t.string  "department"
    t.string  "subject"
    t.string  "number"
    t.string  "asked_by"
    t.string  "question_type"
    t.string  "bill_title"
    t.string  "bill_stage"
    t.string  "type"
    t.string  "chair",             array: true
    t.integer "parent_section_id"
    t.string  "division_number"
    t.string  "tellers_ayes",      array: true
    t.string  "tellers_noes",      array: true
    t.string  "ayes",              array: true
    t.string  "noes",              array: true
  end

  add_index "sections", ["ident"], name: "index_sections_on_ident", using: :btree

end
