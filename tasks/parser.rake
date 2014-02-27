require 'time'

#parser libraries
require './lib/commons/debates_parser'
require './lib/commons/wh_debates_parser'
require './lib/commons/wms_parser'
require './lib/commons/written_answers_parser'
require './lib/commons/petitions_parser'
require './lib/commons/ministerial_corrections_parser'

#persisted models
require './models/daily_part'
require './models/component'
require './models/section'
require './models/paragraph'

#non-persisted models
require './models/hansard_member'
require './models/hansard_page'

desc "scrape a day's worth of hansard"
task :scrape_hansard => :environment do
  date = ENV['date']
  go = true
  
  #make sure date has been supplied and is valid
  unless date
    raise 'need to specify date=yyyy-mm-dd'
  else
    unless date =~ /^\d{4}-\d{2}-\d{2}$/
      raise 'need to specify date=yyyy-mm-dd'
    end
  end
  begin
    Date.parse(date)
  rescue
    warn "invalid date #{date}"
    go = false
  end
  
  if go #great, go
    parser = CommonsDebatesParser.new(date)
    parser.parse
  
    parser = WHDebatesParser.new(date)
    parser.parse
  
    parser = WMSParser.new(date)
    parser.parse
  
    parser = PetitionsParser.new(date)
    parser.parse
  
    parser = WrittenAnswersParser.new(date)
    parser.parse
  
    parser = MinisterialCorrectionsParser.new(date)
    parser.parse
  end
end