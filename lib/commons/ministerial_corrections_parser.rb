require './lib/commons/parser'

class MinisterialCorrectionsParser < CommonsParser
  attr_reader :component_name, :component_prefix
  
  def initialize(date, house="Commons", component_name="Ministerial Corrections")
    super(date)
    @component_name = component_name
    @component_prefix = "mc"
    @department = nil
    @subject = nil
  end
  
  def get_component_index
    super(component_name)
  end
  
  
  private
  
  def parse_node(node)
    case node.name
    when "a"
      process_links_and_columns(node)
      determine_fragment_type(node)
    when "h2"
      setup_preamble(node.content)
    when "h3"
      process_heading(minify_whitespace(node.text))
    when "h4"
      process_subheading(minify_whitespace(node.text))
    when "table"
      process_table(node)
    when "p"
      process_para(node)
    end
  end
  
  def process_heading(text)
    case @page_fragment_type
    when "department heading"
      p
      create_ministerial_correction
      @department = sanitize_text(text)
      @subject = nil
    when "subject heading"
      @subject = sanitize_text(text)
      create_new_noncontribution_para(@subject)
    end
  end
  
  def process_subheading(text)
    if self.state == "starting" and text =~ /[A-Z][a-z+]day \d{1,2} [A-Z][a-z] \d{4}/
      return false
    end
    
    if @section.type == "Preamble"
      start_new_section
      create_new_noncontribution_para(text)
    end
  end
  
  def process_table(node)
    if self.state == "starting"
      return false
    end
    
    if node.xpath("a") and node.xpath("a").length > 0
      @last_link = node.xpath("a").last.attr("name")
    end
    
    member_name, column_desc = get_member_and_column(node)
    
    text = node.text.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
    return false if text.empty?
    #ignore column heading text
    unless text =~ COLUMN_HEADER
      @para_seq += 1
      para_ident = "#{@section.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
      para = nil
      process_member_contribution(member_name, text)
      
      table = NonContributionTable.find_or_create_by(ident: para_ident)
      table.content = node.to_html.gsub(/<a class="[^"]*" name="[^"]*">\s?<\/a>/, "")
      table.column = @column
      table.url = "#{@page.url}\##{@last_link}"
      table.sequence = @para_seq
      table.section = @section
      table.save
      @section.paragraphs << table
    end
  end
  
  def process_para(node)
    return nil unless @section
    
    if node.xpath("a") and node.xpath("a").length > 0
      @last_link = node.xpath("a").last.attr("name")
    end
    
    member_name, column_desc = get_member_and_column(node)
    
    text = node.text.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
    return false if text.empty?
    
    #ignore column heading text
    unless text =~ COLUMN_HEADER
      para = create_new_noncontribution_para(sanitize_text(text))
    end
  end
  
  def create_ministerial_correction
    start_new_section
    
    @section_seq += 1
    section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    @section = MinisterialCorrection.find_or_create_by(ident: section_ident)
    @section.url = "#{@page.url}\##{@last_link}"
    @section.columns = [@column]
    @section.sequence = @section_seq
    @section.component = @hansard_component
    @para_seq = 0
  end
  
  def save_section
    return false unless @section
    
    if @section.type == "MinisterialCorrection"
      @section.department = @department if @department
      @section.title = "Correction - #{@subject}" if @subject
    end
    if @section.columns and @section.columns.length > 2
      @section.columns = [@section.columns.first, @section.columns.last]
    end
    @section.save
    debug()
  end
end