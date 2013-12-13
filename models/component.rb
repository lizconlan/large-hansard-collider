#encoding: utf-8

require 'active_record'

# slightly odd choice of word, but have confirmed that
# Section was misleading
class Component < ActiveRecord::Base
  belongs_to :daily_part
  has_many :fragments
  
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
  
  def contributions_by_member(member_name)
    contribs = []
    contrib = []
    last_ident = ""
    paras = Paragraph.by_member_and_fragment_id_start(member_name, ident).all
    paras.each do |para|
      unless para.contribution_ident == last_ident
        unless contribs.empty? and contrib.empty?
          contribs << contrib
          contrib = []
        end
      end
      contrib << para
      last_ident = para.contribution_ident
    end
    contribs << contrib unless contrib.empty?
    contribs
  end
end