#encoding: utf-8

require 'active_record'

class Fragment < ActiveRecord::Base
  belongs_to :component
  has_many :paragraphs
  
  def contributions_by_member(member_name)
    contribs = []
    contrib = []
    last_id = ""
    paras = Paragraph.by_member_and_fragment_id(member_name, id).all
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

class Debate < Fragment
end

class Statement < Fragment
end

class Question < Fragment
end

class Preamble < Fragment
end

class MemberIntroduction < Fragment
end

class Tributes < Fragment
end