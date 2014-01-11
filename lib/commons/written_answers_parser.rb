require './lib/commons/parser'

class WrittenAnswersParser < CommonsParser
  attr_reader :component_name, :component_prefix
  
  def initialize(date, house="Commons", component_name="Written Answers")
    super(date)
    @component_name = component_name
    @component_prefix = "w"
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
    set_new_heading
    if @page_fragment_type == "department heading"
      @department = sanitize_text(text)
      @subject = nil
    else
      @subject = sanitize_text(text)
    end
    stop_new_heading
  end
  
  def process_subheading(text)
    if self.state == "starting" and text =~ /[A-Z][a-z+]day \d{1,2} [A-Z][a-z] \d{4}/
      return false
    end
    
    if @section.type == "Preamble"
      build_preamble(text)
    end
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
        table = ContributionTable.find_or_create_by(ident: para_ident)
        table.content = node.to_html.gsub(/<a class="[^"]*" name="[^"]*">\s?<\/a>/, "")
        table.member = @member.printed_name
        link_member_to_contribution(@member)
      end
      table.column = @end_column
      table.url = "#{@page.url}\##{@last_link}"
      table.sequence = @para_seq
      table.section = @section
      table.save
      @section.paragraphs << table
    end
  end
  
  def process_para(node)
    column_desc = ""
    member_name = ""
    if node.xpath("a") and node.xpath("a").length > 0
      @last_link = node.xpath("a").last.attr("name")
      determine_fragment_type(node.xpath("a"))
      if @page_fragment_type == "question"
        create_question if @page_fragment_type == "question"
      end
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
        else
          para.speaker_printed_name = @member.printed_name
        end
        para.member = @member.printed_name
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
  
  def create_question
    start_new_section
    
    @section_seq += 1
    section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    @section = Question.find_or_create_by(ident: section_ident)
    @section.question_type = "for written answer"
    @section.title = @subject
    @section.url = "#{@page.url}\##{@last_link}"
    @section.sequence = @section_seq
    @para_seq = 0
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
  
  def save_section
    return false unless @section
    @section.department = @department if @department
    @section.save
    debug()
  end
end