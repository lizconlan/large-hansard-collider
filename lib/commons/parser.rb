#encoding: utf-8

require "./lib/parser.rb"

class CommonsParser
  include Parser
  
  attr_reader :date, :doc_id, :house
  
  COLUMN_HEADER = /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/
  
  def initialize(date)
    super(date, "Commons")
  end
  
  def link_to_first_page
    unless self.respond_to?(:component)
      component = 0
    end
    html = get_component_index(component)
    return nil unless html
    doc = Nokogiri::HTML(html)
    
    content_component = doc.xpath("//div[@id='content-small']/p[3]/a")
    if content_component.empty?
      content_component = doc.xpath("//div[@id='content-small']/table/tr/td[1]/p[3]/a[1]")
    end
    if content_component.empty?
      content_component = doc.xpath("//div[@id='maincontent1']/div/a[1]")
    end
    relative_path = content_component.attr("href").value.to_s
    "http://www.publications.parliament.uk#{relative_path[0..relative_path.rindex("#")-1]}"
  end
  
  private
  
  def process_links_and_columns(node)
    if node.attr("class") == "anchor" or node.attr("name") =~ /^\d*$/
      @last_link = node.attr("name")
    end
    p "link: " + @last_link if @house == "Lords"
    
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
      when "Westminster Hall"
        sequence = 2
      when "Written Ministerial Statements"
        sequence = 3
      when "Petitions"
        sequence = 4
      when "Written Answers"
        sequence = 5
      when "Ministerial Corrections"
        sequence = 6
      else
        raise "unrecognised component: #{component}"
    end
    component
  end
end