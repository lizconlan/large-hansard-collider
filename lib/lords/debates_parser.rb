require './lib/lords/parser'

class LordsDebatesParser < LordsParser
  attr_reader :component, :component_prefix
  
  def initialize(date, component="Debates and Oral Answers")
    super(date)
    @component = component
    @component_prefix = "d"
  end
  
  def get_component_index
    super(component)
  end
  
  def init_vars
    super()
    
    @questions = []
    @question_no = ""
    @petitions = []
    
    @column = ""
    @subcomponent = ""
    @asked_by = ""
    @div_fragment = nil
  end
  
  def reset_vars
    @fragment = []
    @questions = []
    @petitions = []
  end
  
  
  private
  
  def fragment_has_text
    (@fragment.empty? == false and @fragment.map {|x| x.text}.join("").length > 0)
  end
  
  def parse_node(node, page)
    # p "processing node: #{node.name}"
    case node.name
    when "columnnum"
      node.children.each do |child|
        parse_node(child, page)
      end
    when "a"
      process_links_and_columns(node)
      determine_fragment_type(node)
    when "h1", "h2"
      node.xpath("a").each do |child|
        parse_node(child, page)
      end
      process_h2(minify_whitespace(node.text), node.content, page)
    when "h3"
      process_h3(minify_whitespace(node.text), page)
    when "h4"
      process_h4(sanitize_text(minify_whitespace(node.text)), page)
    when "h5"
      process_h5(minify_whitespace(node.text), page)
    when "p", "center"
      process_para(node, page)
    when "div", "hr"
      #ignore
    end
  end
  
  def store_and_reset(page)
    store_debate(page)
    @fragment = []
    @segment_link = ""
    @questions = []
    @petitions = []
    @component_members = {}
  end
  
  def process_h2(text, title, page)
    if fragment_has_text or @intro[:title]
      if @intro[:title] == "House of Lords" and
         text.strip =~ /^[A-Z][a-z]+day, \d+ [A-Z][a-z]+ \d{4}/
        build_intro(text, page.url)
      else
        store_and_reset(page)
      end
    end
    
    if text == "House of Lords"
      setup_intro(text, page.url, text, "h1")
    end
    
    if text =~ /^Introduction:/
      setup_new_fragment(text, page)
    end
    
    if text == "Oral Answers to Questions"
      @subcomponent = "Oral Answer"
      setup_intro(text, page.url, title, "h3")
    end
  end
  
  def process_h3(text, page)
    if (@fragment_type == "department heading" and @subcomponent == "Oral Answer")
      @department = text
      if text.downcase != "prayers" and (fragment_has_text or @intro[:title])
        store_and_reset(page)
        @segment_link = "#{page.url}\##{@last_link}"
      else
        @subject = text
        if @intro[:title]
          build_intro(text, page.url)
        else
          fragment = create_fragment(text)
          @fragment << fragment
          @segment_link = "#{page.url}\##{@last_link}"
        end
      end
    elsif @fragment_type == "subject heading" and @subcomponent == "Oral Answer"
      if (fragment_has_text and @subject != "") or @intro[:title]
        store_and_reset(page)
      end
      @subject = text
      @segment_link = "#{page.url}\##{@last_link}"
    else
      @subcomponent = ""
      if text.downcase == "prayers"
        build_intro(text, page.url)
      else
        if (@fragment.empty? == false) or @intro[:title]
          store_and_reset(page)
        end
        setup_new_fragment(text, page)
      end
    end
  end
  
  def process_h4(text, page)
    day_regex = /^[A-Z][a-z]*day \d{1,2} [A-Z][a-z]* \d{4}$/
    if @intro[:title]
      build_intro(text, page.url)
    else
      if text.downcase =~ /^back\s?bench business$/
        #treat as honourary h3
        if fragment_has_text or @intro[:title]
          store_and_reset(page)
        end
        @intro[:title] = text
        @subcomponent = ""
      else              
        fragment = create_fragment(text)
        @fragment << fragment
        unless @subcomponent == "Oral Answer"
          @subject = sanitize_text(text)
        end
        @segment_link = "#{page.url}\##{@last_link}"
      end
    end
  end
  
  def process_h5(text, page)
    fragment = create_fragment(text)
    fragment.desc = "timestamp"
    fragment.link = "#{page.url}\##{@last_link}"
    @fragment << fragment
  end
  
  def setup_new_fragment(text, page)
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
    when /^introduction\:/
      @subcomponent = "Member Introduction"
    else
      if @subcomponent == ""
        @subcomponent = "Debate"
      end
    end
    unless text.downcase == "petition"
      @subject = text
      @segment_link = "#{page.url}\##{@last_link}"
    end
  end
  
  def stash_division
    @fragment << @div_fragment
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
      @div_fragment = HansardFragment.new
      @div_fragment.desc = "division"
      @div_fragment.text = "division"
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
    end
  end
  
  def process_anchor_element(node)
    if node.xpath("a") and node.xpath("a").length > 0
      @last_link = node.xpath("a").last.attr("name")
      node.xpath("a").each do |anchor|
        case anchor.attr("name")
        when /^qn_/
          @fragment_type = "question"
          @link = node.attr("name")
        when /^st_/, /^stpa_/
          if @fragment_type == "division" and @div_fragment
            stash_division()
          end
          @fragment_type = "contribution"
          @link = node.attr("name")
        when /^divlst_/
          @fragment_type = "division"
          @link = node.attr("name")
        end
      end
    end
  end
  
  def process_oral_question(text, page)
    if text =~ /^((?:T|Q)\d+)\.\s\[([^\]]*)\] /
      qno = $1
      question = $2
      set_subjects_and_store(qno, page)
      @questions << question
    elsif text[text.length-1..text.length] == "]" and text.length > 3
      question = text[text.rindex("[")+1..text.length-2]
      @questions << sanitize_text(question)
    end
  end
  
  def set_subjects_and_store(qno, page)
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
      store_debate(page)
      reset_vars()
    end
    @question_no = qno
    @segment_link = "#{page.url}\##{@last_link}"
    @subject = "#{@subject.gsub(/\- (?:T|Q)\d+/, "- #{@question_no}")}"
  end
  
  def check_debate_contributions(text, member_name, page)
    case member_name
    when /^(([^\(]*) \(in the Chair\):)/
      #the Chair
      name = $2
      post = "Debate Chair"
      member = HansardMember.new(name, name, "", "", post)
      handle_contribution(@member, member, page)
      @contribution.segments << sanitize_text(text.gsub($1, "")).strip
    when /^(([^\(]*) \(([^\(]*)\):)/
      #we has a minister
      post = $2
      name = $3
      member = HansardMember.new(name, "", "", "", post)
      handle_contribution(@member, member, page)
      @contribution.segments << sanitize_text(text.gsub($1, "")).strip
    when /^(([^\(]*) \(([^\(]*)\) \(([^\(]*)\))/
      #an MP speaking for the first time in the debate
      name = $2
      constituency = $3
      party = $4
      member = HansardMember.new(name, "", constituency, party)
      handle_contribution(@member, member, page)
      @contribution.segments << sanitize_text(text.gsub($1, "")).strip
    when /^(([^\(]*):)/
      #an MP who's spoken before
      name = $2
      member = HansardMember.new(name, name)
      handle_contribution(@member, member, page)
      @contribution.segments << sanitize_text(text.gsub($1, "")).strip
    else
      if @member
        unless text =~ /^Sitting suspended|^Sitting adjourned|^On resuming|^Question put/ or
            text == "#{@member.search_name} rose\342\200\224"
          @contribution.segments << sanitize_text(text)
        end
      end
    end
  end
  
  def create_fragment(text)
    fragment = HansardFragment.new
    if @member
      fragment.speaker = @member.index_name
    end
    fragment.text = sanitize_text(text)
    if @end_column.empty?
      fragment.column = @start_column
    else
      fragment.column = @end_column
    end
    
    if @member
      if fragment.text =~ /^((T|Q)?\d+\.\s+(\[\d+\]\s+)?)?#{@member.post} \(#{@member.name}\)/
        fragment.printed_name = "#{@member.post} (#{@member.name})"
      elsif fragment.text =~ /^((T|Q)?\d+\.\s+(\[\d+\]\s+)?)?#{@member.search_name}/
        fragment.printed_name = @member.search_name
      else
        fragment.printed_name = @member.printed_name
      end
      if @fragment_type == "question" and @asked_by.empty?
        @asked_by = @member.index_name
      end
      fragment.text = sanitize_text(text)
    end
    fragment
  end
  
  def format_fragment_html(prefix, fragment)
    if prefix
      pref_length = prefix.length
    else
      pref_length = 0
    end
    "<p>#{prefix}<b>#{@coder.encode(fragment.printed_name, :named)}</b>#{@coder.encode(fragment.text.strip[fragment.printed_name.length+pref_length..fragment.text.strip.length], :named)}</p>"
  end
  
  def process_para(node, page)
    column_desc = ""
    member_name = ""
    
    #check for inner subcomponents
    if @subcomponent == "Debate" and (node.xpath("i") and node.xpath("i").length > 0)
      override_subcomponent(node)
    end
    
    unless @fragment.empty? and node.xpath("center") and node.xpath("center").text == node.text
      process_anchor_element(node)
    end
    
    unless node.xpath("b").empty?
      node.xpath("b").each do |bold|
        if bold.text =~ COLUMN_HEADER  #older page format
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
    
    if @fragment_type == "question"
      process_oral_question(text, page)
    elsif @fragment_type == "division"
      process_division(text)
    end
    if @subcomponent == "Petition" and text =~ /\[(P[^\]]*)\]/
      @petitions << $1
    end
    
    #ignore column heading text
    unless (text =~ COLUMN_HEADER) or text == ""
      #check if this is a new contrib
      check_debate_contributions(text, member_name, page)
      
      if @intro[:title]
        build_intro(text, page.url)
      elsif @fragment_type != "division"
        fragment = create_fragment(text)
        
        @fragment << fragment
        @segment_link = "#{page.url}\##{@last_link}" if @segment_link == ""
      end
    end
  end
  
  def store_non_contribution_para(intro, fragment, idx, para_ident)
    para = NonContributionPara.find_or_create_by(ident: para_ident)
    para.fragment = intro
    para.text = fragment
    para.sequence = @para_seq
    para.url = @intro[:links][idx]
    para.column = @intro[:columns][idx]
    para.save(:safe => true)
    para
  end
  
  def store_intro
    @fragment_seq += 1
    intro_ident = "#{@hansard_component.ident}_#{@fragment_seq.to_s.rjust(6, "0")}"
    intro = Intro.find_or_create_by(ident: intro_ident)
    @para_seq = 0
    intro.title = @intro[:title]
    intro.component = @hansard_component
    intro.url = @intro[:link]
    intro.sequence = @fragment_seq
    
    @intro[:fragments].each_with_index do |fragment, i|
      @para_seq += 1
      para_ident = "#{intro.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
      para = store_non_contribution_para(intro, fragment, i, para_ident)
      intro.paragraphs << para
    end
    cols = intro.paragraphs.map { |x| x.column }.uniq
    cols.delete_if { |x| x.nil? or x.empty? }
    intro.columns = cols
    
    intro.save(:safe => true)
    @hansard_component.fragments << intro
    @hansard_component.save(:safe => true)
    
    @intro = {:fragments => [], :columns => [], :links => []}
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
    
    para.text = "#{fragment.overview} \n #{fragment.timestamp} - Division No. #{fragment.number} \n Ayes: #{fragment.ayes.join("; ")}, Tellers for the Ayes: #{fragment.tellers_ayes}, Noes: #{fragment.noes.join("; ")}, Tellers for the Noes: #{fragment.tellers_noes} \n #{fragment.summary}"
    para
  end
  
  def store_contribution_fragment(fragment, para_ident)
    para = ContributionPara.find_or_create_by(ident: para_ident)
    para.member = fragment.speaker
    para.contribution_ident = "#{@debate.ident}__#{fragment.contribution_seq.to_s.rjust(6, "0")}"
    if fragment.text.strip =~ /^(T?\d+\.\s+(\[\d+\]\s+)?)?#{fragment.printed_name.gsub('(','\(').gsub(')','\)')}/
      para.speaker_printed_name = fragment.printed_name
    end
    para
  end
  
  def store_fragments
    @fragment.each do |fragment|
      unless fragment.text == @debate.title or fragment.text == ""
        @para_seq += 1
        para_ident = "#{@debate.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
        
        para = create_para_by_type(fragment, para_ident)
        associate_members_with_debate() unless @debate.class == MemberIntroduction
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
    @debate.members = col_paras.map {|x| x.member}.uniq unless @debate.members
  end
  
  def assign_para_to_debate(fragment, para)
    para.text = fragment.text
    para.url = fragment.link
    para.column = fragment.column
    para.sequence = @para_seq
    para.fragment = @debate
    para.save(:safe => true)
    
    @debate.paragraphs << para
  end
  
  def store_segment(page)
    @fragment_seq += 1
    segment_ident = "#{@hansard_component.ident}_#{@fragment_seq.to_s.rjust(6, "0")}"
    
    column_text = ""
    if @start_column == @end_column or @end_column == ""
      column_text = @start_column
    else
      column_text = "#{@start_column} to #{@end_column}"
    end
    
    if @subcomponent == "Oral Answer"
      create_question(segment_id)
    elsif @subcomponent == "Member Introduction"
      @debate = MemberIntroduction.find_or_create_by(ident: segment_ident)
      @debate.members = [@subject.gsub("Introduction: ", "")]
    else
      @debate = Debate.find_or_create_by(ident: segment_ident)
    end
    
    @para_seq = 0
    @hansard_component.fragments << @debate
    @hansard_component.save(:safe => true)
    
    @daily_part.volume = page.volume
    @daily_part.part = sanitize_text(page.part.to_s)
    @daily_part.save(:safe => true)
    
    @debate.component = @hansard_component
    @debate.title = @subject
    @debate.url = @segment_link
    
    @debate.sequence = @fragment_seq
    
    store_fragments()
    segment_ident
  end
  
  def store_debate(page)
    unless @questions.empty?
      @subcomponent = "Oral Answer"
    end
    if @intro[:title]
      store_intro()
    else
      unless @fragment.empty?
        handle_contribution(@member, @member, page)
        
        #no point storing pointers that don't link back to the source
        if @segment_link
          segment_ident = store_segment(page)
        end
        
        set_columns_and_save()
        print_debug(segment_ident)
      end
    end
  end
  
  def set_columns_and_save
    @debate.columns = @debate.paragraphs.map {|x| x.column}.uniq
    @debate.save(:safe => true)
    @start_column = @end_column if @end_column != ""
  end
  
  def print_debug(segment_ident)
    unless ENV["RACK_ENV"] == "test"
      p @subject
      p segment_ident
      p @segment_link
      p ""
    end
  end
end