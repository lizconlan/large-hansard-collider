require './lib/commons/parser'

class WrittenAnswersParser < CommonsParser
  attr_reader :component_name, :component_prefix
  
  def initialize(date, house="Commons", component_name="Written Answers")
    super(date)
    @component_name = component_name
    @component_prefix = "w"
  end
  
  def get_component_index
    super(component_name)
  end
  
  def reset_vars
    @page_fragments = []
    @questions = []
    @members = {}
  end
  
  
  private
  
  def parse_node(node, page)
    case node.name
    when "a"
      process_links_and_columns(node)
      determine_fragment_type(node)
    when "h2"
      setup_preamble(node.content, page.url)
    when "h3"
      process_heading(minify_whitespace(node.text), page)
    when "h4"
      process_subheading(minify_whitespace(node.text), page)
    when "table"
      process_table(node, page)
    when "p"
      process_para(node, page)
    end
  end
  
  def process_heading(text, page)
    unless @page_fragments.empty? or @page_fragments.join("").length == 0
      store_debate(page)
      @page_fragments = []
      @segment_link = ""
      @questions = []
      @members = {}
    end
    if @page_fragments_type == "department heading"
      @department = sanitize_text(text)
    else
      @subject = sanitize_text(text)
    end
    @segment_link = "#{page.url}\##{@last_link}"
  end
  
  def process_subheading(text, page)
    if @preamble[:title]
      @preamble[:fragments] << text
      @preamble[:columns] << @end_column
      @preamble[:links] << "#{page.url}\##{@last_link}"
    else          
      unless @page_fragments.empty? or @page_fragments.join("").length == 0
        store_debate(page)
        @page_fragments = []
        @questions = []
        @segment_link = ""
        @members = {}
      end
      
      @subject = sanitize_text(text)
      @segment_link = "#{page.url}\##{@last_link}"
      
      fragment = PageFragment.new
      fragment.content = sanitize_text(text)
      fragment.column = @end_column
      @page_fragments << fragment
    end
  end
  
  def process_table(node, page)
    if node.xpath("a") and node.xpath("a").length > 0
      @last_link = node.xpath("a").last.attr("name")
    end
    
    fragment = PageFragment.new
    fragment.content = node.to_html.gsub(/<a class="[^"]*" name="[^"]*">\s?<\/a>/, "")
    fragment.link = "#{page.url}\##{@last_link}"
    
    if @member
      fragment.speaker = @member.printed_name
    end
    fragment.column = @end_column
    fragment.contribution_seq = @contribution_seq
    @page_fragments << fragment
  end
  
  def process_para(node, page)
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
    #ignore column heading text
    unless text =~ COLUMN_HEADER
      if text[text.length-1..text.length] == "]" and text.length > 3
        question = text[text.rindex("[")+1..text.length-2]
        @questions << sanitize_text(question)
      end
      
      #check if this is a new contrib
      process_member_contribution(member_name, text, page)
      
      fragment = PageFragment.new
      fragment.content = sanitize_text(text)
      fragment.link = "#{page.url}\##{@last_link}"
      if @member
        if fragment.content =~ /^#{@member.post} \(#{@member.name}\)/
          fragment.printed_name = "#{@member.post} (#{@member.name})"
        elsif fragment.content =~ /^#{@member.search_name}/
          fragment.printed_name = @member.search_name
        else
          fragment.printed_name = @member.printed_name
        end
        fragment.speaker = @member.printed_name
      end
      fragment.column = @end_column
      fragment.contribution_seq = @contribution_seq
      @page_fragments << fragment
    end
  end
  
  def store_debate(page)
    if @preamble[:title]
      store_preamble(page)
    else
      handle_contribution(@member, @member, page)
      
      if @segment_link #no point storing pointers that don't link back to the source
        @page_fragments_seq += 1
        segment_ident = "#{@hansard_component.ident}_#{@page_fragments_seq.to_s.rjust(6, "0")}"
        
        column_text = ""
        if @start_column == @end_column or @end_column == ""
          column_text = @start_column
        else
          column_text = "#{@start_column} to #{@end_column}"
        end
        
        @question = Question.find_or_create_by(ident: segment_ident)
        @question.question_type = "for written answer"
        @para_seq = 0
        @hansard_component.fragments << @question
        @hansard_component.save
        
        @daily_part.volume = page.volume
        @daily_part.part = sanitize_text(page.part.to_s)
        @daily_part.save
        
        @question.component = @hansard_component
        
        @question.title = @subject
        @question.department = @department
        @question.url = @segment_link
        @question.number = @questions.last
        
        @question.sequence = @page_fragments_seq
        
        @page_fragments.each do |fragment|
          unless fragment.content == @question.title or fragment.content == ""
            @para_seq += 1
            para_ident = "#{@question.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
            
            case fragment.desc
            when "timestamp"
              para = Timestamp.find_or_create_by(ident: para_ident)
              para.content = fragment.content
            else
              if fragment.speaker.nil?
                para = NonContributionPara.find_or_create_by(ident: para_ident)
                para.content = fragment.content
              elsif fragment.content.strip[0..5] == "<table"
                para = ContributionTable.find_or_create_by(ident: para_ident)
                para.member = fragment.speaker
                para.contribution_ident = "#{@question.ident}__#{fragment.contribution_seq.to_s.rjust(6, "0")}"
                
                table = Nokogiri::HTML(fragment.content)
                para.content = table.content
              else
                para = ContributionPara.find_or_create_by(ident: para_ident)
                para.member = fragment.speaker
                para.contribution_ident = "#{@question.ident}__#{fragment.contribution_seq.to_s.rjust(6, "0")}"
                if fragment.content.strip =~ /^#{fragment.printed_name.gsub('(','\(').gsub(')','\)')}/
                  para.speaker_printed_name = fragment.printed_name
                end
                para.content = fragment.content
              end
            end
            
            para.url = fragment.link
            para.column = fragment.column
            para.sequence = @para_seq
            para.fragment = @question
            para.save
            
            @question.paragraphs << para
          end
        end
        
        @question.columns = @question.paragraphs.collect{|x| x.column}.uniq
        col_paras = @question.paragraphs.dup
        col_paras.delete_if{|x| x.respond_to?("member") == false }
        @question.members = col_paras.collect{|x| x.member}.uniq
        @question.save
        @start_column = @end_column if @end_column != ""
        
        unless ENV["RACK_ENV"] == "test"
          p @subject
          p segment_ident
          p @segment_link
          p ""
        end
      end
    end
  end
end