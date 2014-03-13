#encoding: utf-8

require 'active_record'

class Section < ActiveRecord::Base
  belongs_to :component
  has_many :paragraphs
  has_many :sections, :foreign_key => 'parent_section_id', :dependent => :destroy
  belongs_to :parent_section, :class_name => "Section", :foreign_key => 'parent_section_id'
  
  def append_column(col, wrapper=nil)
    if self.columns.nil?
      self.columns = [col]
    else
      self.columns << col unless self.columns.include?(col)
      wrapper.columns << col if wrapper and !(wrapper.columns.include?(col))
    end
  end
  
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

class Container < Section
end

class Debate < Section
end

class Statement < Section
end

class Petition < Section
end

class PetitionObservation < Section
end

class MinisterialCorrection < Section
end

class Question < Section
end

class Preamble < Section
end

class MemberIntroduction < Section
end

class Tribute < Section
end

class Division < Section
end

class SectionGroup < Section
end

class QuestionGroup < Section
end