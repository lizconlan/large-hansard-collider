require './lib/commons/parser'

class WMSParser < CommonsParser
  attr_reader :component_name, :component_prefix
  
  def initialize(date, house="Commons", component_name="Written Ministerial Statements")
    super(date)
    @component_name = component_name
    @component_prefix = "wms"
    @department = nil
  end
  
  def get_component_index
    super("Written Statements")
  end
  
  
  private
  
  def parse_node(node)
    case node.name
    when "h2"
      setup_preamble(node.text)
    when "a"
      process_links_and_columns(node)   
    when "h3"
      process_department_heading(minify_whitespace(node.text))
    when "h4"
      process_statement_heading(minify_whitespace(node.text))
    when "table"
      process_table(node)
    when "p"
      process_para(node)
    end
  end
  
  def process_department_heading(text)
    set_new_heading
    @section_seq += 1
    section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    @section = Statement.find_or_create_by(ident: section_ident)
    @section.component = @hansard_component
    @section.columns = [@column]
    @section.sequence = @section_seq
    @department = sanitize_text(text)
    @section.url = "#{@page.url}\##{@last_link}"
  end
  
  def process_statement_heading(text)
    if @section.type == "Preamble"
      create_new_noncontribution_para(text)
    else
      if self.state == "setting_heading"
        stop_new_heading
      else
        start_new_section
        @section_seq += 1
        section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
        @section = Statement.find_or_create_by(ident: section_ident)
        @section.component = @hansard_component
        @section.columns = [@column]
        @section.sequence = @section_seq
        @section.url = "#{@page.url}\##{@last_link}"
      end
      @section.title = sanitize_text(text)
      @para_seq = 0
    end
  end
  
  def process_table(node)
    if self.state == "starting"
      return false
    end
    
    if node.xpath("a") and node.xpath("a").length > 0
      @last_link = node.xpath("a").last.attr("name")
    end
    
    @para_seq += 1
    para_ident = "#{@section.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
    para = nil
    
    if @member
      para = ContributionTable.find_or_create_by(ident: para_ident)
      para.member = @member.index_name
      add_member_to_temp_store(@member)
    else
      para = NonContributionTable.find_or_create_by(ident: para_ident)
    end
    content = sanitize_text(node.to_html)
    para.content = content.gsub(/<a class="[^"]*" name="[^"]*">\s?<\/a>/, "")
    para.column = @column
    para.url = "#{@page.url}\##{@last_link}"
    para.section = @section
    para.sequence = @para_seq
    para.save
    @section.paragraphs << para
  end
  
  def process_para(node)
    if self.state == "starting"
      return false
    end
    
    if node.xpath("a") and node.xpath("a").length > 0
      @last_link = node.xpath("a").last.attr("name")
    end
    
    member_name, column_desc = get_member_and_column(node)
    
    text = sanitize_text(node.text)
    return false if text.empty?
    #ignore column heading text
    unless text.strip =~ COLUMN_HEADER
      text = text.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
      process_member_contribution(member_name, text)
      
      if @member
        para = create_new_contribution_para(sanitize_text(text), member_name)
      else
        para = create_new_noncontribution_para(sanitize_text(text))
      end
    end
  end
  
  def save_section
    return false unless @section
    @section.department = @department if @department
    if @section.columns and @section.columns.length > 2
      @section.columns = [@section.columns.first, @section.columns.last]
    end
    @section.save
    debug()
  end
  
  def debug()
    unless ENV["RACK_ENV"] == "test"
      p ""
      p "Type: #{@section.type}"
      p "title: #{@section.title ? @section.title : "nil"}"
      p "ident: #{@section.ident ? @section.ident : "nil"}"
      p "url: #{@section.url ? @section.url : "nil"}"
      p "****"
    end
  end
end