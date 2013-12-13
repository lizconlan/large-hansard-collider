#encoding: utf-8

require "./lib/parser.rb"

class LordsParser
  include Parser
  attr_reader :date, :doc_id, :house
  
  COLUMN_HEADER = /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:GC)?(?:WS)?(?:P)?(?:WA)?)(?:-continued)?$/
  
  def initialize(date)
    super(date, "Lords")
  end
  
  def link_to_first_page
    unless self.respond_to?(:component)
      component = 0
    end
    html = get_component_index(component)
    
    return nil unless html
    doc = Nokogiri::HTML(html)
    
    anchor_name = @start_url.split("#").last
    preceding_link = doc.xpath("//a[@name='#{anchor_name}']").first
    next_element = preceding_link.next_sibling()
    next_element.xpath("a/@href").first.value
  end
  
  private
  
  def process_links_and_columns(node)
    unless node.attr("href")
      @last_link = node.attr("name")
    end
    
    column = set_column(node)
    
    if @start_column.empty? and column
      #need to set the start column
      @start_column = set_column(node)
    elsif column
      #need to set the end column
      @end_column = set_column(node)
    end
  end
  
  def set_column(node)
    if node.attr("class") == "anchor-column"
      return node.attr("name").gsub("column_", "")
    elsif node.attr("name") =~ /column_(.*)/  #older page format
      return node.attr("name").gsub("column_", "")
    end
    false
  end
  
  def get_sequence(component)
    sequence = nil
    case component
      when "Debates and Oral Answers"
        sequence = 1
      when "Grand Committee"
        sequence = 2
      when "Written Statements"
        sequence = 3
      when "Written Answers"
        sequence = 4
      else
        raise "unrecognised component: #{component}"
    end
    component
  end
end