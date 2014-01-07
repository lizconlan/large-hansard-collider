require './lib/commons/parser'

class CommonsDebatesParser < CommonsParser
  attr_reader :component_name, :component_prefix
  
  def initialize(date, component_name="Debates and Oral Answers")
    super(date)
    @component_name = component_name
    @component_prefix = "d"
  end
  
  def get_component_index
    super(component_name)
  end
  
  def init_vars
    super()
    
    @bill = {}
    
    @questions = []
    @question_no = ""
    @petitions = []
    
    @column = ""
    @subcomponent = ""
    @asked_by = ""
    @div_fragment = nil
  end
  
  def reset_vars
    @page_fragments = []
    @questions = []
    @petitions = []
    @section_link = ""
    @component_members = {}
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
    when "div", "hr"
      #ignore
    end
  end
  
  def process_top_level_heading(text, title)
    case text
    when "House of Commons"
      setup_preamble(title, @page.url)
    when "Oral Answers to Questions"
      set_new_heading
      @subcomponent = "Oral Answer"
      setup_preamble(title, @page.url)
    end
  end
  
  def process_heading(text)
    if (@page_fragments_type == "department heading" and @subcomponent == "Oral Answer")
      @department = text
      if text.downcase != "prayers" and (fragment_has_text or @preamble[:title])
        set_new_heading
        
        @section_link = "#{@page.url}\##{@last_link}"
      else
        start_new_section
        @subject = text
        
        if @preamble[:title]
          build_preamble(text, @page.url)
        else
          fragment = create_fragment(text)
          @page_fragments << fragment
          @section_link = "#{@page.url}\##{@last_link}"
        end
      end
    elsif @page_fragments_type == "subject heading" and @subcomponent == "Oral Answer"
      start_new_section
      @subject = text
      @section_link = "#{@page.url}\##{@last_link}"
    else
      if text =~ /.? Bill(?: |$)/
        @bill[:title] = text.gsub(" [Lords]", "")
      end
      
      @subcomponent = ""
      if text.downcase == "prayers"
        build_preamble(text, @page.url)
      else
        start_new_section
        setup_new_fragment(text)
      end
    end
  end
  
  def process_subheading(text)
    day_regex = /^[A-Z][a-z]*day \d{1,2} [A-Z][a-z]* \d{4}$/
    if @preamble[:title]
      build_preamble(text, @page.url)
    else
      if text.downcase =~ /^back\s?bench business$/
        #treat as honorary h3 / main heading
        if fragment_has_text or @preamble[:title]
          set_new_heading
        end
        @preamble[:title] = text
        @subcomponent = ""
      else              
        fragment = create_fragment(text)
        @page_fragments << fragment
        unless @subcomponent == "Oral Answer"
          @subject = sanitize_text(text)
        end
        @section_link = "#{@page.url}\##{@last_link}"
      end
    end
  end
  
  def process_timestamp(text)
    fragment = create_fragment(text)
    fragment.desc = "timestamp"
    fragment.link = "#{@page.url}\##{@last_link}"
    @page_fragments << fragment
  end
  
  def setup_new_fragment(text)
    case text.downcase
    when "business without debate"
      @subcomponent = ""
    when /^business/,
         "european union documents",
         "points of order",
         "point of order",
         "royal assent",
         "bill presented"
      @subject = text
      @subcomponent = ""
    when "petition"
      @subcomponent = "Petition"
    when /adjournment/
      @subcomponent = "Adjournment Debate"
    else
      if @subcomponent == ""
        @subcomponent = "Debate"
      end
    end
    unless text.downcase == "petition"
      @subject = text
      @section_link = "#{@page.url}\##{@last_link}"
    end
  end
  
  def stash_division
    @page_fragments << @div_fragment
    @div_fragment = nil
  end
  
  def process_division(text)
    case text.strip
    when /^(Question|Motion)/
      @div_fragment.summary = text
      if @div_fragment
        stash_division()
      end
    when /^The House (having )?divided/
      @div_fragment = PageFragment.new
      @div_fragment.desc = "division"
      @div_fragment.content = "division"
      @div_fragment.overview = text
      @div_fragment.ayes = []
      @div_fragment.noes = []
      @div_fragment.tellers_ayes = ""
      @div_fragment.tellers_noes = ""
    when /^Ayes \d+, Noes \d+./
      @div_fragment.overview = "#{@div_fragment.overview} #{text}".strip
    when /^Division No\. ([^\]]*)\]/
      @div_fragment.number = $1
    when /\[(\d+\.\d+ (a|p)m)/
      @div_fragment.timestamp = $1
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
        @div_fragment.ayes << text.strip
      else
        @div_fragment.noes << text.strip
      end
    else
      if @tellers
        if @current_list == "ayes"
          @div_fragment.tellers_ayes = "#{@div_fragment.tellers_ayes} #{text.strip}".strip
        else
          @div_fragment.tellers_noes = "#{@div_fragment.tellers_noes} #{text.strip}".strip
        end
      else
        if @current_list == "ayes"
          aye = @div_fragment.ayes.pop
          aye = "#{aye} #{text.strip}"
          @div_fragment.ayes << aye
        else
          noe = @div_fragment.noes.pop
          noe = "#{noe} #{text.strip}"
          @div_fragment.noes << noe
        end
      end
    end
  end
  
  def override_subcomponent(node)
    case node.xpath("i").first.text.strip
    when /^Motion/
      unless (node.xpath("i").map { |x| x.text }).join(" ") =~ /and Question p/
        @subcomponent = "Motion"
        @member = nil
      end
    when /^Debate resumed/
      @subject = "#{@subject} (resumed)"
      @member = nil
    when /^Ordered/, /^Question put/
      @subcomponent = ""
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
          @page_fragments_type = "question"
          @link = node.attr("name")
        when /^st_/, /^stpa_/
          if @page_fragments_type == "division" and @div_fragment
            stash_division()
          end
          @page_fragments_type = "contribution"
          @link = node.attr("name")
        when /^divlst_/
          @page_fragments_type = "division"
          @link = node.attr("name")
        end
      end
    end
  end
  
  def process_oral_question(text)
    if text =~ /^((?:T|Q)\d+)\.\s\[([^\]]*)\] /
      qno = $1
      question = $2
      set_subjects_and_store(qno)
      @questions << question
    elsif text[text.length-1..text.length] == "]" and text.length > 3
      question = text[text.rindex("[")+1..text.length-2]
      @questions << sanitize_text(question)
    end
  end
  
  def set_subjects_and_store(qno)
    if @questions.empty?
      if @subject =~ /\- (?:T|Q)\d+/
        @subject = "#{@subject.gsub(/\- (?:T|Q)\d+/, "- #{qno}")}"
      else
        @subject = "#{@subject} - #{qno}"
      end
    else
      if @subject =~ /\- (?:T|Q)\d+/
        @subject = "#{@subject.gsub(/\- (?:T|Q)\d+/, "- #{@question_no}")}"
      else
        @subject = "#{@subject} - #{@question_no}"
      end
      save_section
      reset_vars()
    end
    @question_no = qno
    @section_link = "#{@page.url}\##{@last_link}"
    @subject = "#{@subject.gsub(/\- (?:T|Q)\d+/, "- #{@question_no}")}"
  end
  
  def create_fragment(text)
    fragment = PageFragment.new
    if @member
      fragment.speaker = @member.index_name
    end
    fragment.content = sanitize_text(text)
    fragment.column = @end_column
    
    if @member
      if fragment.content =~ /^((T|Q)?\d+\.\s+(\[\d+\]\s+)?)?#{@member.post} \(#{@member.name}\)/
        fragment.printed_name = "#{@member.post} (#{@member.name})"
      elsif fragment.content =~ /^((T|Q)?\d+\.\s+(\[\d+\]\s+)?)?#{@member.search_name}/
        fragment.printed_name = @member.search_name
      else
        fragment.printed_name = @member.printed_name
      end
      if @page_fragments_type == "question" and @asked_by.empty?
        @asked_by = @member.index_name
      end
      fragment.content = sanitize_text(text)
    end
    fragment
  end
  
  def process_para(node)
    column_desc = ""
    member_name = ""
    
    #check for inner subcomponents
    if @subcomponent == "Debate" and (node.xpath("i") and node.xpath("i").length > 0)
      override_subcomponent(node)
    end
    
    unless @page_fragments.empty? and node.xpath("center") and node.xpath("center").text == node.text
      process_anchor_element(node)
    end
    
    unless node.xpath("b").empty?
      node.xpath("b").each do |bold|
        if bold.text =~ COLUMN_HEADER #older page format
          if @start_column.empty?
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
    
    text = scrub_whitespace_and_column_refs(node.content, column_desc)
    
    if @page_fragments_type == "question"
      process_oral_question(text)
    elsif @page_fragments_type == "division"
      process_division(text)
    end
    if @subcomponent == "Petition" and text =~ /\[(P[^\]]*)\]/
      @petitions << $1
    end
    
    #ignore column heading text
    unless (text =~ COLUMN_HEADER) or text == ""
      #check if this is a new contrib
      process_member_contribution(member_name, text)
      
      if @preamble[:title]
        build_preamble(text, @page.url)
      elsif @page_fragments_type != "division"
        fragment = create_fragment(text)
        
        @page_fragments << fragment
        @section_link = "#{@page.url}\##{@last_link}" if @section_link == ""
      end
    end
  end
  
  def store_non_contribution_para(preamble, fragment, idx, para_ident)
    para = NonContributionPara.find_or_create_by(ident: para_ident)
    para.section = preamble
    para.content = fragment
    para.sequence = @para_seq
    para.url = @preamble[:links][idx]
    para.column = @preamble[:columns][idx]
    
    para.save
    para
  end
  
  def store_preamble
    @page_fragments_seq += 1
    preamble_ident = "#{@hansard_component.ident}_#{@page_fragments_seq.to_s.rjust(6, "0")}"
    preamble = Preamble.find_or_create_by(ident: preamble_ident)
    @para_seq = 0
    preamble.title = @preamble[:title]
    preamble.component = @hansard_component
    preamble.url = @preamble[:link]
    preamble.sequence = @page_fragments_seq
    
    @preamble[:fragments].each_with_index do |fragment, i|
      @para_seq += 1
      para_ident = "#{preamble.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
      para = store_non_contribution_para(preamble, fragment, i, para_ident)
      preamble.paragraphs << para
    end
    preamble.columns = preamble.paragraphs.map { |x| x.column }.uniq
    
    preamble.save
    @hansard_component.sections << preamble
    @hansard_component.save
    
    @preamble = {:fragments => [], :columns => [], :links => []}
  end
  
  def create_question(q_ident)
    @debate = Question.find_or_create_by(ident: q_ident)
    @debate.number = @questions.last
    @debate.department = @department
    @debate.asked_by = @asked_by
    @debate.question_type = "for oral answer"
    @asked_by = ""
  end
  
  def store_division_fragment(fragment, para_ident)
    para = Division.find_or_create_by(ident: para_ident)
    para.number = fragment.number
    para.ayes = fragment.ayes
    para.noes = fragment.noes
    para.tellers_ayes = fragment.tellers_ayes
    para.tellers_noes = fragment.tellers_noes
    para.timestamp = fragment.timestamp
    
    para.content = "#{fragment.overview} \n #{fragment.timestamp} - Division No. #{fragment.number} \n Ayes: #{fragment.ayes.join("; ")}, Tellers for the Ayes: #{fragment.tellers_ayes}, Noes: #{fragment.noes.join("; ")}, Tellers for the Noes: #{fragment.tellers_noes} \n #{fragment.summary}"
    para
  end
  
  def store_contribution_fragment(fragment, para_ident)
    para = ContributionPara.find_or_create_by(ident: para_ident)
    para.member = fragment.speaker
    para.contribution_ident = "#{@debate.ident}__#{fragment.contribution_seq.to_s.rjust(6, "0")}"
    if fragment.content.strip =~ /^(T?\d+\.\s+(\[\d+\]\s+)?)?#{fragment.printed_name.gsub('(','\(').gsub(')','\)')}/
      para.speaker_printed_name = fragment.printed_name
    end
    para
  end
  
  def store_fragments
    @page_fragments.each do |fragment|
      unless fragment.content == @debate.title or fragment.content == ""
        @para_seq += 1
        para_ident = "#{@debate.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
        
        para = create_para_by_type(fragment, para_ident)
        associate_members_with_debate()
        assign_para_to_debate(fragment, para)
      end
    end
  end
  
  def create_para_by_type(fragment, para_ident)
    case fragment.desc
    when "timestamp"
      para = Timestamp.find_or_create_by(ident: para_ident)
    when "division"
      para = store_division_fragment(fragment, para_ident)
    else
      if fragment.speaker.nil?
        para = NonContributionPara.find_or_create_by(ident: para_ident)
      else
        para = store_contribution_fragment(fragment, para_ident)
      end
    end
    para
  end
  
  def associate_members_with_debate
    col_paras = @debate.paragraphs.dup
    col_paras.delete_if{|x| x.respond_to?("member") == false }
    @debate.members = col_paras.map {|x| x.member}.uniq
  end
  
  def assign_para_to_debate(fragment, para)
    para.content = fragment.content
    para.url = fragment.link
    para.column = fragment.column
    para.sequence = @para_seq
    para.section = @debate
    para.save
    
    @debate.paragraphs << para
  end
  
  def store_current_section
    @page_fragments_seq += 1
    section_ident = "#{@hansard_component.ident}_#{@page_fragments_seq.to_s.rjust(6, "0")}"
    
    column_text = ""
    if @start_column == @end_column or @end_column == ""
      column_text = @start_column
    else
      column_text = "#{@start_column} to #{@end_column}"
    end
    
    if @subcomponent == "Oral Answer"
      create_question(section_ident)
    else
      @debate = Debate.find_or_create_by(ident: section_ident)
    end
    
    @para_seq = 0
    @hansard_component.sections << @debate
    @hansard_component.save
    
    @daily_part.volume = @page.volume
    @daily_part.part = sanitize_text(@page.part.to_s)
    @daily_part.save
    
    @debate.component = @hansard_component
    @debate.title = @subject
    @debate.url = @section_link
    
    @debate.sequence = @page_fragments_seq
    
    store_fragments()
    section_ident
  end
  
  def save_section
    return false unless @preamble[:title] or fragment_has_text
    
    unless @questions.empty?
      @subcomponent = "Oral Answer"
    end
    
    if @preamble[:title]
      store_preamble()
    else
      unless @page_fragments.empty?
        handle_contribution(@member, @member)
        
        #no point storing pointers that don't link back to the source
        unless @section_link.empty?
          section_ident = store_current_section
        end
        
        set_columns_and_save()
        print_debug(section_ident)
      end
    end
    reset_vars
  end
  
  def set_columns_and_save
    @debate.columns = @debate.paragraphs.map {|x| x.column}.uniq
    if @bill[:title]
      @debate.bill_title = @bill[:title]
      @debate.bill_stage = @bill[:stage]
      @bill = {}
    end
    @debate.save
    @start_column = @end_column if @end_column != ""
  end
  
  def print_debug(section_ident)
    unless ENV["RACK_ENV"] == "test"
      p @subject
      p section_ident
      p @section_link
      p ""
    end
  end
end