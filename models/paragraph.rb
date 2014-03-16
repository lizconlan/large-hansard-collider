#encoding: utf-8

require 'active_record'

class Paragraph < ActiveRecord::Base
  belongs_to :section
end

class Timestamp < Paragraph
end

class ContributionPara < Paragraph
end

class NonContributionPara < Paragraph
end

class ContributionTable < Paragraph
end

class NonContributionTable < Paragraph
end