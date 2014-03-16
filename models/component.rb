#encoding: utf-8

require 'active_record'

class Component < ActiveRecord::Base
  belongs_to :daily_part
  has_many :sections
  
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
end