#encoding: utf-8

require 'active_record'

class Paragraph < ActiveRecord::Base
  belongs_to :section
  
  def self.by_member(member_name)
    where(:_type => "ContributionPara", :member => member_name)
  end
  
  def self.by_member_and_section_id(member_name, section_id)
    where(:_type => "ContributionPara", :member => member_name, :section_id => section_id).sort(:sequence)
  end
  
  def self.by_member_and_section_id_start(member_name, section_start)
    where(:_type => "ContributionPara", :member => member_name, :section_id => /^#{section_start}/).sort(:section_id, :sequence)
  end
end

class Timestamp < Paragraph
end

class ContributionPara < Paragraph
end

class NonContributionPara < Paragraph
end

class ContributionTable < Paragraph
end

class Division < Paragraph
end