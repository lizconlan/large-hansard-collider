require './lib/commons/parser'

class WMSParser < CommonsParser
  attr_reader :component, :component_prefix
  
  def initialize(date, house="Commons", component="Written Ministerial Statements")
    super(date)
    @component = component
    @component_prefix = "wms"
  end
  
  def get_component_index
    super("Written Statements")
  end
  
  def reset_vars
    @fragment = []
    @members = {}
    @component_members = {}
  end
  
  
  private
  
  def parse_node(node, page)
    case node.name
    when "h2"
      setup_preamble(node.text, page.url)
    when "a"
      process_links_and_columns(node)   
    when "h3"
      process_department_heading(minify_whitespace(node.text), page)
    when "h4"
      process_statement_heading(minify_whitespace(node.text), page)
    when "table"
      process_table(node, page)
    when "p"
      process_para(node, page)
    end
  end
  
  def process_department_heading(text, page)
    unless @fragment.empty? or @fragment.join("").length == 0
      store_debate(page)
      @fragment = []
      @segment_link = ""
    end
    
    @department = sanitize_text(text)          
    @segment_link = "#{page.url}\##{@last_link}"
  end
  
  def process_statement_heading(text, page)
    if @preamble[:title]
      @preamble[:fragments] << text
      @preamble[:columns] << @end_column
      @preamble[:links] << "#{page.url}\##{@last_link}"
    else
      unless @fragment.empty? or @fragment.join("").length == 0
        store_debate(page)
        @fragment = []
        @segment_link = ""
      end
      
      @subject = sanitize_text(text)
      @segment_link = "#{page.url}\##{@last_link}"
    end
  end
  
  def process_table(node, page)
    if node.xpath("a") and node.xpath("a").length > 0
      @last_link = node.xpath("a").last.attr("name")
    end
    
    fragment = HansardFragment.new
    fragment.content = node.to_html.gsub(/<a class="[^"]*" name="[^"]*">\s?<\/a>/, "")
    fragment.link = "#{page.url}\##{@last_link}"
    
    if @member
      fragment.speaker = @member.index_name
    end
    fragment.column = @end_column
    fragment.contribution_seq = @contribution_seq
    @fragment << fragment
  end
  
  def process_para(node, page)
    column_desc = ""
    member_name = ""
    if node.xpath("a") and node.xpath("a").length > 0
      @last_link = node.xpath("a").last.attr("name")
    end
    unless node.xpath("b").empty?
      node.xpath("b").each do |bold|
        if bold.text =~ COLUMN_HEADER  #older page format
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
      #check if this is a new contrib
      process_member_contribution(member_name, text, page)
      
      fragment = HansardFragment.new
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
        fragment.speaker = @member.index_name
      end
      fragment.column = @end_column
      fragment.contribution_seq = @contribution_seq
      @fragment << fragment
    end
  end
  
  def store_debate(page)
    if @preamble[:title]
      @fragment_seq += 1
      preamble_ident = "#{@hansard_component.ident}_#{@fragment_seq.to_s.rjust(6, "0")}"
      preamble = Preamble.find_or_create_by(ident: preamble_ident)
      @para_seq += 1
      preamble.title = @preamble[:title]
      preamble.component = @hansard_component
      preamble.url = @preamble[:link]
      preamble.sequence = @fragment_seq
      
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
      handle_contribution(@member, @member, page)
      
      if @segment_link #no point storing pointers that don't link back to the source
        @fragment_seq += 1
        segment_ident = "#{@hansard_component.ident}_#{@fragment_seq.to_s.rjust(6, "0")}"
                      
        column_text = ""
        if @start_column == @end_column or @end_column == ""
          column_text = @start_column
        else
          column_text = "#{@start_column} to #{@end_column}"
        end
        
        @statement = Statement.find_or_create_by(ident: segment_ident)
        @para_seq = 0
        @hansard_component.fragments << @statement
        @hansard_component.save
        
        @daily_part.volume = page.volume
        @daily_part.part = sanitize_text(page.part.to_s)
        @daily_part.save
        
        @statement.component = @hansard_component
        
        @statement.title = @subject
        @statement.department = @department
        @statement.url = @segment_link
        
        @statement.sequence = @fragment_seq
        
        @fragment.each do |fragment|
          unless fragment.content == @statement.title or fragment.content == ""
            @para_seq += 1
            para_ident = "#{@statement.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
            
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
                para.contribution_ident = "#{@statement.ident}__#{fragment.contribution_seq.to_s.rjust(6, "0")}"
                
                table = Nokogiri::HTML(fragment.content)
                para.content = table.content
              else
                para = ContributionPara.find_or_create_by(ident: para_ident)
                para.member = fragment.speaker
                para.contribution_ident = "#{@statement.ident}__#{fragment.contribution_seq.to_s.rjust(6, "0")}"
                if fragment.content.strip =~ /^#{fragment.printed_name.gsub('(','\(').gsub(')','\)')}/
                  para.speaker_printed_name = fragment.printed_name
                end
                para.content = fragment.content
              end
            end
            
            para.url = fragment.link
            para.column = fragment.column
            para.sequence = @para_seq
            para.fragment = @statement
            para.save
            
            @statement.paragraphs << para
          end
        end
        
        @statement.columns = @statement.paragraphs.collect{|x| x.column}.uniq
        @statement.members = @statement.paragraphs.collect{|x| x.member}.uniq
        @statement.save
        @start_column = @end_column if @end_column != ""
        
        unless ENV["RACK_ENV"] == "test"
          p @subject
          p segment_ident
          p @segment_link
          p ""
        end
      end
    end
    reset_vars()
  end
end