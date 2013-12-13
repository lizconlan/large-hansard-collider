#encoding: utf-8

require 'active_record'

class Paragraph < ActiveRecord::Base
  belongs_to :fragment
  
  def self.by_member(member_name)
    where(:_type => "ContributionPara", :member => member_name)
  end
  
  def self.by_member_and_fragment_id(member_name, fragment_id)
    where(:_type => "ContributionPara", :member => member_name, :fragment_id => fragment_id).sort(:sequence)
  end
  
  def self.by_member_and_fragment_id_start(member_name, fragment_start)
    where(:_type => "ContributionPara", :member => member_name, :fragment_id => /^#{fragment_start}/).sort(:fragment_id, :sequence)
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