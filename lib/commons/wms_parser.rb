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
    @department = sanitize_text(text)
    @section.url = "#{@page.url}\##{@last_link}"
  end
  
  def process_statement_heading(text)
    if @section.type == "Preamble"
      build_preamble(text)
    else
      if self.state == "setting_heading"
        stop_new_heading
      else
        start_new_section
        @section_seq += 1
        section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
        @section = Statement.find_or_create_by(ident: section_ident)
        @section.url = "#{@page.url}\##{@last_link}"
      end
      @section.title = sanitize_text(text)
      @para_seq = 0
    end
  end
  
  def setup_preamble(title)
    start_preamble
    @section_seq += 1
    section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    @section = Preamble.find_or_create_by(ident: section_ident)
    @section.title = title
    @section.url = @page.url
    @section.sequence = @section_seq
    @section.component = @hansard_component
    @section.columns = []
    @para_seq = 0
  end
  
  def build_preamble(text)
    @para_seq +=1
    para_ident = "#{@section.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
    para = NonContributionPara.find_or_create_by(ident: para_ident)
    para.sequence = @para_seq
    para.content = text
    para.url = "#{@page.url}\##{@last_link}"
    para.section = @section
    if @end_column.empty?
      @section.columns << @start_column
      para.column = @start_column
    else
      @section.columns << @end_column
      para.column = @end_column
    end
    para.save
    @section.paragraphs << para
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
      para.content = node.to_html.gsub(/<a class="[^"]*" name="[^"]*">\s?<\/a>/, "")
      para.member = @member.index_name
      link_member_to_contribution(@member)
    end
    para.content = node.to_html.gsub(/<a class="[^"]*" name="[^"]*">\s?<\/a>/, "")
    para.column = @end_column
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
    
    column_desc = ""
    member_name = ""
    if node.xpath("a") and node.xpath("a").length > 0
      @last_link = node.xpath("a").last.attr("name")
    end
    
    unless node.xpath("b").empty?
      node.xpath("b").each do |bold|
        if bold.text =~ COLUMN_HEADER #older page format
          if @start_column == ""
            @start_column = $1
          else
            @end_column = $1
          end
          column_desc = bold.text
        else 
          member_name = bold.text.strip
        end
      end
    else
      member_name = ""
    end
    
    text = node.text.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
    return false if text.empty?
    #ignore column heading text
    unless text =~ COLUMN_HEADER
      @para_seq += 1
      para_ident = "#{@section.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
      para = nil
      
      #check if this is a new contrib
      process_member_contribution(member_name, text)
      
      if @member
        para = ContributionPara.find_or_create_by(ident: para_ident)
        para.content = sanitize_text(text)
        
        if sanitize_text(text).strip =~ /^#{@member.post} \(#{@member.name}\)/
          para.speaker_printed_name = "#{@member.post} (#{@member.name})"
        end
        para.member = @member.index_name
        link_member_to_contribution(@member)
      else
        para = NonContributionPara.find_or_create_by(ident: para_ident)
        para.content = sanitize_text(text)
      end
      para.column = @end_column
      para.url = "#{@page.url}\##{@last_link}"
      para.sequence = @para_seq
      para.section = @section
      para.save
      @section.paragraphs << para
    end
  end
  
  def save_section
    return false unless @section
    @section.department = @department if @department
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