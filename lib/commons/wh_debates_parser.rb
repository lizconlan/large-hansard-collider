require './lib/commons/parser'

class WHDebatesParser < CommonsParser
  attr_reader :component_name, :component_prefix
  
  def initialize(date, house="Commons", component_name="Westminster Hall")
    super(date)
    @component_name = component_name
    @component_prefix = "wh"
  end
  
  def get_component_index
    super(component_name)
  end
  
  def reset_vars
    @page_fragments = []
  end
  
  
  private
  
  def parse_node(node)
    case node.name
    when "h2"
      setup_preamble(node.content, @page.url)
    when "a"
      process_links_and_columns(node)
    when "h3"
      create_new_fragment(minify_whitespace(node.text))
    when "h4"
      process_subheading(minify_whitespace(node.text))
    when "h5"
      process_timestamp(node.text)
    when "p" 
      process_para(node)
    end
  end
  
  def create_new_fragment(text)
    unless @page_fragments.empty?
      save_fragment
      @page_fragments = []
      @segment_link = ""
    end
    fragment = PageFragment.new
    fragment.content = sanitize_text(text)
    fragment.column = @end_column
    @page_fragments << fragment
    @subject = sanitize_text(text)
    @segment_link = "#{@page.url}\##{@last_link}"
  end
  
  def process_subheading(text)
    if text[text.length-13..text.length-2] == "in the Chair"
      @chair = text[1..text.length-15]
    end
    if @preamble[:title]
      @preamble[:fragments] << text
      @preamble[:columns] << @end_column
      @preamble[:links] << "#{@page.url}\##{@last_link}"
    end
  end
  
  def process_timestamp(text)
    fragment = PageFragment.new
    fragment.content = text
    fragment.desc = "timestamp"
    fragment.column = @end_column
    fragment.link = "#{@page.url}\##{@last_link}"
    @page_fragments << fragment
  end
  
  def process_para(node)
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
    
    text = node.content.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
    if node.xpath("i").first
      italic_text = node.xpath("i").first.content
    else
      italic_text = ""
    end
    
    if text[text.length-13..text.length-2] == "in the Chair"
      @chair = text[1..text.length-15]
    end
    
    #ignore column heading text
    unless text =~ COLUMN_HEADER
      #check if this is a new contrib
      process_member_contribution(member_name, text, true, italic_text)
      
      fragment = PageFragment.new
      fragment.content = sanitize_text(text)
      fragment.link = "#{@page.url}\##{@last_link}"
      if @member
        if fragment.content =~ /^#{@member.post} \(#{@member.name}\)/
          fragment.printed_name = "#{@member.post} (#{@member.name})"
        elsif fragment.content =~ /^#{@member.search_name}/
          fragment.printed_name = @member.search_name
        else
          fragment.printed_name = @member.printed_name
        end
        fragment.speaker = @member.index_name
      end
      fragment.column = @end_column
      fragment.contribution_seq = @contribution_seq
      @page_fragments << fragment
    end
  end
  
  def save_fragment
    if @preamble[:title]
      @page_fragments_seq += 1
      preamble_ident = "#{@hansard_component.ident}_#{@page_fragments_seq.to_s.rjust(6, "0")}"
      preamble = Preamble.find_or_create_by(ident: preamble_ident)
      preamble.title = @preamble[:title]
      preamble.component = @hansard_component
      preamble.url = @preamble[:link]
      preamble.sequence = @page_fragments_seq
      
      @preamble[:fragments].each_with_index do |fragment, i|
        @para_seq += 1
        para_ident = "#{preamble.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
        
        para = NonContributionPara.find_or_create_by(ident: para_ident)
        para.fragment = preamble
        para.content = fragment
        para.sequence = @para_seq
        para.url = @preamble[:links][i]
        para.column = @preamble[:columns][i]
        
        para.save
        preamble.paragraphs << para
      end
      preamble.columns = preamble.paragraphs.collect{ |x| x.column }.uniq
      
      preamble.save
      @hansard_component.fragments << preamble
      @hansard_component.save
      
      @preamble = {:fragments => [], :columns => [], :links => []}
    else
      handle_contribution(@member, @member)
      
      if @segment_link #no point storing pointers that don't link back to the source
        @page_fragments_seq += 1
        segment_ident = "#{@hansard_component.ident}_#{@page_fragments_seq.to_s.rjust(6, "0")}"
        
        names = []
        @members.each { |x, y| names << y.index_name unless names.include?(y.index_name) }
        
        column_text = ""
        if @start_column == @end_column or @end_column == ""
          column_text = @start_column
        else
          column_text = "#{@start_column} to #{@end_column}"
        end
        
        @debate = Debate.find_or_create_by(ident: segment_ident)
        @para_seq = 0
        @hansard_component.fragments << @debate
        @hansard_component.save
        
        @daily_part.volume = @page.volume
        @daily_part.part = sanitize_text(@page.part.to_s)
        @daily_part.save
        
        @debate.component = @hansard_component
        @debate.members = names
        
        @debate.title = @subject
        @debate.chair = @chair
        @debate.url = @segment_link
        
        @debate.sequence = @page_fragments_seq
        
        @page_fragments.each do |fragment|
          unless fragment.content == @debate.title or fragment.content == ""
            @para_seq += 1
            para_ident = "#{@debate.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
            
            case fragment.desc
            when "timestamp"
              para = Timestamp.find_or_create_by(ident: para_ident)
            else
              if fragment.speaker.nil?
                para = NonContributionPara.find_or_create_by(ident: para_ident)
              else
                para = ContributionPara.find_or_create_by(ident: para_ident)
                para.member = fragment.speaker
                para.contribution_ident = "#{@debate.ident}__#{fragment.contribution_seq.to_s.rjust(6, "0")}"
                if fragment.content.strip =~ /^#{fragment.printed_name.gsub('(','\(').gsub(')','\)')}/
                  para.speaker_printed_name = fragment.printed_name
                end
              end
            end
            
            para.content = fragment.content
            para.url = fragment.link
            para.column = fragment.column
            para.sequence = @para_seq
            para.fragment = @debate
            para.save
            
            @debate.paragraphs << para
          end
        end
        
        @debate.columns = @debate.paragraphs.collect{|x| x.column}.uniq
        @debate.save
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