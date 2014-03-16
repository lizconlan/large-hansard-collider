#encoding: utf-8

require 'active_record'

class DailyPart < ActiveRecord::Base
  has_many :components
end