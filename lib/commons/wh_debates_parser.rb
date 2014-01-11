require './lib/commons/parser'

class WHDebatesParser < CommonsParser
  attr_reader :component_name, :component_prefix
  
  def initialize(date, house="Commons", component_name="Westminster Hall")
    super(date)
    @component_name = component_name
    @component_prefix = "wh"
    @chair = ""
  end
  
  def get_component_index
    super(component_name)
  end
  
  
  private
  
  def parse_node(node)
    case node.name
    when "h2"
      setup_preamble(node.text)
    when "a"
      process_links_and_columns(node)
    when "h3"
      create_new_debate(minify_whitespace(node.text))
    when "h4"
      process_subheading(minify_whitespace(node.text))
    when "h5"
      process_timestamp(node.text)
    when "p" 
      process_para(node)
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
  
  def create_new_debate(text)
    start_new_section
    
    @section_seq += 1
    section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    @section = Debate.find_or_create_by(ident: section_ident)
    @section.title = sanitize_text(text)
    @section.chair = @chair
    @section.url = "#{@page.url}\##{@last_link}"
    @section.sequence = @section_seq
    @section.columns = [@end_column]
    @para_seq = 0
  end
  
  def process_subheading(text)
    if text[text.length-13..text.length-2] == "in the Chair"
      @chair = text[1..text.length-15]
    end
    if @section.type == "Preamble"
      build_preamble(text)
    end
  end
  
  def process_timestamp(text)
    return false unless @section
    
    @para_seq +=1
    ts_ident = "#{@section.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
    timestamp = Timestamp.find_or_create_by(ident: ts_ident)
    timestamp.content = text
    timestamp.column = @end_column
    timestamp.url = "#{@page.url}\##{@last_link}"
    timestamp.section = @section
    timestamp.sequence = @para_seq
    timestamp.save
    
    @section.paragraphs << timestamp
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
          if @start_column.empty?
            @start_column = $1
            @end_column = $1
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
    
    text = node.content.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
    if node.xpath("i").first
      italic_text = node.xpath("i").first.content
    else
      italic_text = ""
    end

    if text[text.length-13..text.length-2] == "in the Chair"
      @chair = text[1..text.length-15]
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
        else
          para.speaker_printed_name = @member.printed_name
        end
        para.member = @member.index_name
        link_member_to_contribution(@member)
      else
        para = NonContributionPara.find_or_create_by(ident: para_ident)
        para.content = sanitize_text(text)
      end
      if @end_column.empty?
        para.column = @start_column
      else
        para.column = @end_column
      end
      para.url = "#{@page.url}\##{@last_link}"
      para.sequence = @para_seq
      para.section = @section
      para.save
      @section.paragraphs << para
    end
  end
  
  def save_section
    return false unless @section
    @section.save
    debug()
  end
end