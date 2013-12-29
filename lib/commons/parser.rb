#encoding: utf-8

require "./lib/parser.rb"

class CommonsParser
  include Parser
  
  attr_reader :date, :doc_id, :house
  
  COLUMN_HEADER = /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/
  
  def initialize(date)
    super(date, "Commons")
  end
  
  def get_component_links
    parse_date = Date.parse(date)
    index_page = "http://www.parliament.uk/business/publications/hansard/#{house.downcase()}/by-date/?d=#{parse_date.day}&m=#{parse_date.month}&y=#{parse_date.year}"
    urls = Hash.new
    
    html = get_page(index_page)
    
    if html
      doc = Nokogiri::HTML(html)
      doc.xpath("//ul[@class='publications']/li/a").each do |link|
        urls["#{link.text.strip}"] = link.attribute("href").value.to_s
      end
    end
    urls
  end
  
  def link_to_first_page
    unless self.respond_to?(:component)
      component = 0
    end
    html = get_component_index
    return nil unless html
    doc = Nokogiri::HTML(html)
    
    content_component = doc.xpath("//div[@id='content-small']/p[3]/a")
    if content_component.empty?
      content_component = doc.xpath("//div[@id='content-small']/table/tr/td[1]/p[3]/a[1]")
    end
    if content_component.empty?
      content_component = doc.xpath("//div[@id='maincontent1']/div/a[1]")
    end
    relative_path = content_component.attr("href").value.to_s
    "http://www.publications.parliament.uk#{relative_path[0..relative_path.rindex("#")-1]}"
  end
  
  
  private
  
  def process_links_and_columns(node)
    if node.attr("class") == "anchor" or node.attr("name") =~ /^\d*$/
      @last_link = node.attr("name")
    end
    
    column = set_column(node)
    if @start_column.empty? and column
      #need to set the start column
      @start_column = set_column(node)
    elsif column
      #need to set the end column
      @end_column = set_column(node)
    end
  end
  
  def process_member_contribution(member_name, text, page, seq=nil, italic_text=nil)
    case member_name
    when /^(([^\(]*) \(in the Chair\):)/
      #the Chair
      name = $2
      post = "Debate Chair"
      member = HansardMember.new(name, name, "", "", post)
      handle_contribution(@member, member, page)
      if seq
        @contribution_seq += 1
      else
        @contribution.segments << sanitize_text(text.gsub($1, "")).strip
      end
    when /^(([^\(]*) \(([^\(]*)\):)/
      #we has a minister
      post = $2
      name = $3
      member = HansardMember.new(name, "", "", "", post)
      handle_contribution(@member, member, page)
      if seq
        @contribution_seq += 1
      else
        @contribution.segments << sanitize_text(text.gsub($1, "")).strip
      end
    when /^(([^\(]*) \(([^\(]*)\) \(([^\(]*)\):)/
      #an MP speaking for the first time in the debate
      name = $2
      constituency = $3
      party = $4
      member = HansardMember.new(name, "", constituency, party)
      handle_contribution(@member, member, page)
      if seq
        @contribution_seq += 1
      else
        @contribution.segments << sanitize_text(text.gsub($1, "")).strip
      end
    when /^(([^\(]*):)/
      #an MP who's spoken before
      name = $2
      member = HansardMember.new(name, name)
      handle_contribution(@member, member, page)
      if seq
        @contribution_seq += 1
      else
        @contribution.segments << sanitize_text(text.gsub($1, "")).strip
      end
    else
      if italic_text
        if text == "#{member_name} #{italic_text}".squeeze(" ")
          member = HansardMember.new(member_name, member_name)
          handle_contribution(@member, member, page)
          @contribution_seq += 1
        end
      else
        if @member
          unless text =~ /^Sitting suspended|^Sitting adjourned|^On resuming|^Question put/ or
              text == "#{@member.search_name} rose\342\200\224"
            @contribution.segments << sanitize_text(text)
          end
        end
      end
    end
  end
  
  def get_sequence(component)
    sequence = nil
    case component
      when "Debates and Oral Answers"
        sequence = 1
      when "Westminster Hall"
        sequence = 2
      when "Written Ministerial Statements"
        sequence = 3
      when "Petitions"
        sequence = 4
      when "Written Answers"
        sequence = 5
      when "Ministerial Corrections"
        sequence = 6
      else
        raise "unrecognised component: #{component}"
    end
    component
  end
end