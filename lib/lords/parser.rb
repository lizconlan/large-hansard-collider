#encoding: utf-8

require "./lib/parser.rb"

class LordsParser < Parser
  attr_reader :date, :doc_id, :house
  
  COLUMN_HEADER = /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:GC)?(?:WS)?(?:P)?(?:WA)?)(?:-continued)?$/
  
  def initialize(date)
    super(date, "Lords")
  end
  
  def link_to_first_page
    unless self.respond_to?(:section)
      section = 0
    end
    html = get_section_index(section)
    
    return nil unless html
    doc = Nokogiri::HTML(html)
    
    anchor_name = @start_url.split("#").last
    preceding_link = doc.xpath("//a[@name='#{anchor_name}']").first
    next_element = preceding_link.next_sibling()
    next_element.xpath("a/@href").first.value
  end
  
  private
  
  def get_sequence(section)
    sequence = nil
    case section
      when "Debates and Oral Answers"
        sequence = 1
      when "Grand Committee"
        sequence = 2
      when "Written Statements"
        sequence = 3
      when "Written Answers"
        sequence = 4
      else
        raise "unrecognised section: #{section}"
    end
    section
  end
end