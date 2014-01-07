#encoding: utf-8

require "./lib/parser.rb"

class LordsParser < Parser
  attr_reader :date, :doc_id, :house
  
  COLUMN_HEADER = /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:GC)?(?:WS)?(?:P)?(?:WA)?)(?:-continued)?$/
  
  def initialize(date)
    super(date, "Lords")
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
    elsif node.attr("name") =~ /column_(.*)/ #older page format
      return node.attr("name").gsub("column_", "")
    end
    false
  end
  
  def get_sequence(component_name)
    sequence = nil
    case component_name
      when "Debates and Oral Answers"
        sequence = 1
      when "Grand Committee"
        sequence = 2
      when "Written Statements"
        sequence = 3
      when "Written Answers"
        sequence = 4
      else
        raise "unrecognised component: #{component_name}"
    end
    sequence
  end
end