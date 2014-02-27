require './lib/commons/parser'

class CommonsDebatesParser < CommonsParser
  attr_reader :component_name, :component_prefix
  
  def initialize(date, component_name="Debates and Oral Answers")
    super(date)
    @component_name = component_name
    @component_prefix = "d"
    @department = ""
    @bill = {}
    @subsection_name = ""
    @section_stack = []
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
      process_top_level_heading(minify_whitespace(node.text), node.content)
    when "h3"
      process_heading(minify_whitespace(node.text))
    when "h4"
      process_subheading(sanitize_text(minify_whitespace(node.text)))
    when "h5"
      process_timestamp(minify_whitespace(node.text))
    when "p", "center"
      process_para(node)
    end
  end
  
  def process_top_level_heading(text, title)
    case text
    when "House of Commons"
      setup_preamble(title)
    when "Oral Answers to Questions"
      create_oral_answers_subsection(text)
    end
  end
  
  def process_heading(text)
    if (@page_fragment_type == "department heading" and @subsection_name == "Oral Answer")
      @department = text
      if text.downcase != "prayers" and @section
        start_new_section
        @section = create_new_container(text, @section_stack.last)
      else
        if @section.type == "Preamble"
          #wait, is that even possible?
          create_new_noncontribution_para(text)
        else
          start_new_section
          setup_preamble(text)
        end
      end
    elsif @page_fragment_type == "subject heading" and @subsection_name == "Oral Answer"
      if text == "Topical Questions"
        start_subsection
        @subsection_name = "Topical Questions"
        @section = create_new_container(sanitize_text(text), @section_stack.last)
      else
        #a subject heading, inside Oral Answers
        start_new_section
        @section = create_new_question(sanitize_text(text))
      end
      @section.sequence = @section_seq
      @section.columns = [@column]
      @section.department if @department
    else
      if @subsection_name == "Oral Answer" or @subsection_name == "Topical Questions"
        save_section
      end
      if text =~ /.? Bill(?: |$)/
        @bill[:title] = text.gsub(" [Lords]", "")
      end
      
      @subsection_name = ""
      if text.downcase == "prayers"
        start_new_section
        setup_preamble(text)
      else
        start_new_section
        @section = create_new_debate(sanitize_text(text))
      end
    end
  end
  
  def process_subheading(text)
    if @section and @section.type == "Preamble"
      create_new_noncontribution_para(text)
    else
      if text.downcase =~ /^back\s?bench business$/ \
          or text.downcase =~ /^business without debate$/i
        #treat as honorary h3 / main heading
        @subsection_name = "Backbench Business"
        start_subsection
        @section = create_new_container(text)
      else
        para = create_new_noncontribution_para(sanitize_text(text))
        @subject = sanitize_text(text)
      end
    end
  end
  
  def create_new_debate(text)
    @section_seq += 1
    section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    section = Debate.find_or_create_by(ident: section_ident)
    section.title = text
    section.url = "#{@page.url}\##{@last_link}"
    section.sequence = @section_seq
    section.columns = [@column]
    section.component = @hansard_component
    @para_seq = 0
    section
  end
  
  def create_new_division
    @section_seq += 1
    section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    section = Division.find_or_create_by(ident: section_ident)
    section.title = "Division - #{@section.title}" #borrow the previous section's title, certain assumption there
    section.url = "#{@page.url}\##{@last_link}"
    section.ayes = []
    section.noes = []
    section.tellers_ayes = []
    section.tellers_noes = []
    section.component = @hansard_component
    @para_seq = 0
    section
  end
  
  def create_new_container(title, parent=nil)
    @section_seq += 1
    section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    section = Container.find_or_create_by(ident: section_ident)
    section.url = "#{@page.url}\##{@last_link}"
    section.component = @hansard_component
    section.title = title
    section.sequence = @section_seq
    section.columns = []
    @para_seq = 0
    if parent
      section.parent_section = parent
      parent.sections << section unless parent.sections.include?(section)
      @section_stack << section
    else
      @section_stack = [section]
    end
    section
  end
  
  def create_new_question(text, member=false)
    @section_seq += 1
    section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    section = Question.find_or_create_by(ident: section_ident)
    section.question_type = "for oral answer"
    if section.number.blank?
      number = get_question_number(text)
      unless number.blank?
        section.number = number
      end
    end
    section.asked_by = member.index_name if member
    if text =~ /^\s?(T\d+).(?: |\[)/
      section.title = "Topical Questions - #{$1}"
    else
      section.title = text
    end
    section.sequence = @section_seq
    section.component = @hansard_component
    section.department = @department if @department
    section.url = "#{@page.url}\##{@last_link}"
    @para_seq = 0
    section
  end
  
  def process_division(text)
    case text.strip
    when /^The House (having )?divided/, /^Motion/, /^Question/
      para = create_new_noncontribution_para(sanitize_text(text))
    when /^Ayes \d+, Noes \d+./
      para = create_new_noncontribution_para(sanitize_text(text))
    when /^Division No\. ([^\]]*)\]/
      @section.number = $1
    when /\[(\d+\.\d+ (a|p)m)/
      process_timestamp($1)
    when "AYES"
      @current_list = "ayes"
      @tellers = false
    when "NOES"
      @current_list = "noes"
      @tellers = false
    when "", COLUMN_HEADER
      #ignore
    when /^Tellers for the (Ayes|Noes):/
      @tellers = true
    when /^(?:d(?:e|u|')\s)?(?:Ma?c)?(?:(?:o|O)')?[A-Z][a-z]+(?:(?:\-| )?(?:Ma?c)?[A-Z][a-z]*)?, (?:rh)?\s?(?:Mr|Ms|Mrs|Miss|Dr|Sir)?\s?[A-Z][a-z]*/
      if @current_list == "ayes"
        @section.ayes << text.strip
      else
        @section.noes << text.strip
      end
    else
      if @tellers
        if @current_list == "ayes"
          @section.tellers_ayes << text.strip.gsub(/ and$/, "")
        else
          @section.tellers_noes << text.strip.gsub(/ and$/, "")
        end
      else
        if @current_list == "ayes"
          aye = @section.ayes.pop
          aye = "#{aye} #{text.strip}"
          @section.ayes << aye
        elsif @current_list == "noes"
          noe = @section.noes.pop
          noe = "#{noe} #{text.strip}"
          @section.noes << noe
        else
          para = create_new_noncontribution_para(sanitize_text(text))
        end
      end
    end
  end
  
  def override_subsection(node)
    case node.xpath("i").first.text.strip
    when /^Motion/
      unless (node.xpath("i").map { |x| x.text }).join(" ") =~ /and Question p/
        start_subsection
        @subsection_name = "Motion"
        @member = nil
      end
    when /^Debate resumed/
      @subject = "#{@subject} (resumed)"
      @member = nil
    when /^Ordered/, /^Question put/
      @subsection_name = ""
      @member = nil
    when /Reading$/
      if @bill[:title]
        @bill[:stage] = node.xpath("i").first.text.strip
      end
    end
  end
  
  def process_anchor_element(node)
    if node.xpath("a") and node.xpath("a").length > 0
      @last_link = node.xpath("a").last.attr("name")
      node.xpath("a").each do |anchor|
        case anchor.attr("name")
        when /^qn_/
          @page_fragment_type = "question"
          @link = node.attr("name")
        when /^st_/, /^stpa_/
          @page_fragment_type = "contribution"
          @link = node.attr("name")
        when /^divlst_/
          @page_fragment_type = "division"
          @link = node.attr("name")
        end
      end
    end
  end
  
  def create_oral_answers_subsection(text)
    start_subsection
    @subsection_name = "Oral Answer"
    @section = create_new_container(text)
  end
  
  def get_question_number(text)
    question = ""
    if text =~ /^((?:T|Q)\d+)\.\s\[([^\]]*)\] /
      qno = $1
      question = $2
    elsif text[text.length-1..text.length] == "]" and text.length > 3
      question = text[text.rindex("[")+1..text.length-2]
    end
    question
  end
  
  # def get_question_title(text, number)
  #   title = ""
  #   if text =~ /\- (?:T|Q)\d+/
  #     title = "#{text.gsub(/\- (?:T|Q)\d+/, "- #{number}")}"
  #   else
  #     title = "#{text} - #{number}"
  #   end
  #   title
  # end
  
  def process_para(node)
    column_desc = ""
    member_name = ""
    
    #check for nested sections
    if @section and @section.type == "Debate" and (node.xpath("i") and node.xpath("i").length > 0)
      override_subsection(node)
    end
    
    unless node.xpath("center") and node.xpath("center").text == node.text
      process_anchor_element(node)
    end
    
    unless node.xpath("a").empty?
      process_links_and_columns(node.xpath("a").last)
    end
    
    member_name, column_desc = get_member_and_column(node, true)
    
    text = scrub_whitespace_and_column_refs(node.content, column_desc)
    
    if @page_fragment_type == "question"
      if @subsection_name == "Oral Answer"
        @section.number = get_question_number(text) if @section.number.blank?
        @section.asked_by = @member.index_name
      end
      if @subsection_name == "Topical Questions"
        @section_stack << @section if @section.type == "Container"
        @page_fragment_type = ""
        start_new_section
        @section = create_new_question(text, @member)
      end
    elsif @page_fragment_type == "division"
      unless @section.type == "Division"
        start_new_section
        @section = create_new_division
      end
      process_division(text)
    end
    if @subsection_name == "Petition" and text =~ /\[(P[^\]]*)\]/
      @petitions << $1
    end
    
    #ignore column heading text
    unless (text =~ COLUMN_HEADER) or text == ""
      process_member_contribution(member_name, text)
      
      if @section.type == "Preamble"
        create_new_noncontribution_para(text)
      elsif @page_fragment_type != "division"
        @para_seq += 1
        para_ident = "#{@section.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
        para = nil
        
        if @member
          para = create_new_contribution_para(sanitize_text(text), member_name, para_ident)
        else
          para = create_new_noncontribution_para(sanitize_text(text), para_ident)
        end
      end
    end
  end
  
  def save_section
    return false unless @section
    unless @section_stack.empty? or @section_stack.last == @section
      @section.parent_section = @section_stack.last
      @section_stack.last.sections << @section
      @section_stack.last.save
    end
    if @bill[:title] and @bill[:stage]
      @section.bill_title = @bill[:title]
      @section.bill_stage = @bill[:stage]
      @bill = {}
    end
    
    if @section.columns.length > 2
      @section.columns = [@section.columns.first, @section.columns.last]
    end
    
    @page_fragment_type = "" if @section.type == "Division"
    
    @section.save
  end
end