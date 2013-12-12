#encoding: utf-8

require 'mongo_mapper'

# slightly odd choice of word, but have confirmed that
# Section was misleading
class Component
  include MongoMapper::Document
  
  belongs_to :daily_part
  many :fragments, :in => :fragment_ids, :order => :sequence
  
  def date
    daily_part.date
  end
  
  def volume
    daily_part.volume
  end
  
  def part
    daily_part.part
  end
  
  def house
    daily_part.house
  end
  
  key :fragment_ids, Array
  key :name, String
  key :sequence, Integer
  key :url, String
  
  def contributions_by_member(member_name)
    contribs = []
    contrib = []
    last_id = ""
    paras = Paragraph.by_member_and_fragment_id_start(member_name, id).all
    paras.each do |para|
      unless para.contribution_id == last_id
        unless contribs.empty? and contrib.empty?
          contribs << contrib
          contrib = []
        end
      end
      contrib << para
      last_id = para.contribution_id
    end
    contribs << contrib unless contrib.empty?
    contribs
  end
end