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
      setup_preamble(node.content) unless @section_seq > 1
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
    if text =~ /[A-Z][a-z+]day \d{1,2} [A-Z][a-z] \d{4}/
      if self.state == "starting" or @section_seq > 1
        return false
      end
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
      
      if @member
        table = ContributionTable.find_or_create_by(ident: para_ident)
        table.content = node.to_html.gsub(/<a class="[^"]*" name="[^"]*">\s?<\/a>/, "")
        table.member = @member.printed_name
        add_member_to_temp_store(@member)
      end
      table.column = @column unless @column.empty?
      table.url = "#{@page.url}\##{@last_link}"
      table.sequence = @para_seq
      table.section = @section
      table.save
      @section.paragraphs << table
    end
  end
  
  def process_para(node)
    if node.xpath("a") and node.xpath("a").length > 0
      @last_link = node.xpath("a").last.attr("name")
      determine_fragment_type(node.xpath("a"))
      if @page_fragment_type == "question"
        create_question if @page_fragment_type == "question"
      end
    end
    
    member_name, column_desc = get_member_and_column(node)
    
    text = node.text.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
    return false if text.empty?
    #ignore column heading text
    unless text =~ COLUMN_HEADER
      process_member_contribution(member_name, text)
      
      if @section.type == "Question" and @section.number.nil?
        number = get_question_number(text)
        unless number.empty?
          @section.number = number
        end
      end
      
      if @member
        para = create_new_contribution_para(sanitize_text(text), member_name)
      else
        para = create_new_noncontribution_para(sanitize_text(text))
      end
    end
  end
  
  def get_question_number(text)
    question = ""
    if text.strip =~ /\[([^\]]*)\]$/
      question = $1
    end
    question
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
    @section.component = @hansard_component
    @para_seq = 0
  end
  
  def save_section
    return false unless @section
    @section.department = @department if @department
    if @section.columns.length > 2
      @section.columns = [@section.columns.first, @section.columns.last]
    end
    @section.save
    debug()
  end
end