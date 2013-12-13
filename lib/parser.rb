#encoding: utf-8

require 'htmlentities'
require 'rest-client'
require 'nokogiri'

require './models/hansard_page'
require './models/hansard_member'

require './models/daily_part'
require './models/component'
require './models/fragment'
require './models/paragraph'

module Parser
  attr_reader :date, :doc_id, :house
  
  def initialize(date, house)
    @date = date
    @house = house
    @doc_ident = "#{date}_hansard_#{house[0..0].downcase()}"
    
    @daily_part = DailyPart.find_or_create_by(ident: @doc_ident)
    @daily_part.house = house
    @daily_part.date = date
    @hansard_component = nil
    @fragment = nil
    @element = nil
    @current_speaker = ""
    @start_url = ""
    
    @coder = HTMLEntities.new
  end
  
  def init_vars
    @page = 0
    @component_seq = 0
    @fragment_seq = 0
    @para_seq = 0
    @contribution_seq = 0

    @members = {}
    @component_members = {}
    @member = nil
    @contribution = nil
    
    @last_link = ""
    @fragment = []
    @questions = []
    @intro = {:fragments => [], :columns => [], :links => []}
    @subject = ""
    @start_column = ""
    @end_column = ""
    @chair = ""
    @department = ""
  end
  
  def reset_vars
  end
  
  def get_component_index(component)
    url = get_component_links[component]
    if url
      @start_url = url
      return get_page(url)
    end
  end
  
  def get_page(url)
    begin
      result = RestClient.get(url)
    rescue
      return nil
    end
    result.body
  end
  
  def get_component_links
    parse_date = Date.parse(date)
    index_page = "http://www.parliament.uk/business/publications/hansard/#{house.downcase()}/by-date/?d=#{parse_date.day}&m=#{parse_date.month}&y=#{parse_date.year}"
    urls = Hash.new
    
    html = get_page(index_page)
    if html
      doc = Nokogiri::HTML(html)
      doc.xpath("//ul[@class='event-list']/li/h3/a").each do |link|
        urls["#{link.text.strip}"] = link.attribute("href").value.to_s
      end
    end
    urls
  end
  
  def parse_page(page)
    @page += 1
    content = page.doc.xpath("//div[@id='content-small']")
    if content.empty?
      content = page.doc.xpath("//div[@id='maincontent1']")
    elsif content.children.size < 10
      content = page.doc.xpath("//div[@id='content-small']/table/tr/td[1]")
    end
    content.children.each do |child|
      if child.class == Nokogiri::XML::Element
        parse_node(child, page)
      end
    end
  end
  
  def parse_pages
    init_vars()
    first_page = link_to_first_page
    
    unless first_page
      warn "No #{@component} data available for this date".squeeze(' ')
    else
      create_first_component()
      
      page = HansardPage.new(first_page)
      parse_page(page)
      while page.next_url
        page = HansardPage.new(page.next_url)
        parse_page(page)
      end
      
      #flush the buffer
      if @fragment.empty? == false or @intro[:title]
        store_debate(page)
        reset_vars()
      end
    end
  end
  
  
  private
  
  def minify_whitespace(text)
    text.gsub("\n", "").squeeze(" ").strip
  end
  
  def scrub_whitespace_and_column_refs(text, column_ref)
    text.gsub("\n", " ").gsub("\r", "").gsub(column_ref, "").squeeze(" ").strip
  end
  
  def set_column(node)
    if node.attr("class") == "anchor-column"
      return node.attr("name").gsub("column_", "")
    elsif node.attr("name") =~ /column_(.*)/  #older page format
      return node.attr("name").gsub("column_", "")
    end
    false
  end
  
  def create_first_component
    if component_prefix.empty?
      component_ident = @doc_ident
    else
      component_ident = "#{@doc_ident}_#{component_prefix}"
    end
    
    @hansard_component = Component.find_or_create_by(ident: component_ident)
    @hansard_component.url = @start_url
    @fragment_seq = 0
    @hansard_component.daily_part = @daily_part
    
    @hansard_component.sequence = get_sequence(@component)
    
    @daily_part.components << @hansard_component
    @daily_part.save(:safe => true)
    
    @hansard_component.name = @component
    @hansard_component.save(:safe => true)
  end
  
  def setup_intro(text, url, title, tag)
    @intro[:title] = title
    @intro[:link] = "#{url}\##{@last_link}"
  end
  
  def build_intro(text, url)
    @intro[:fragments] << text
    if @end_column.empty?
      @intro[:columns] << @start_column
    else
      @intro[:columns] << @end_column
    end
    @intro[:links] << "#{url}\##{@last_link}"
  end
  
  def get_sequence(component)
  end
  
  def determine_fragment_type(node)
    case node.attr("name")
    when /^hd_/
      #heading e.g. the date, The House met at..., The Deputy PM was asked
      @fragment_type = "heading"
      @link = node.attr("name")
    when /^place_/
      @fragment_type = "location heading"
      @link = node.attr("name")
    when /^dpthd_/
      @fragment_type = "department heading"
      @link = node.attr("name")
    when /^subhd_/
      @fragment_type = "subject heading"
      @link = node.attr("name")
    when /^qn_/
      @fragment_type = "question"
      @link = node.attr("name")
    when /^st_/
      @fragment_type = "contribution"
      @link = node.attr("name")
    when /^divlst_/
      @fragment_type = "division"
      @link = node.attr("name")
    end 
  end
  
  def handle_contribution(member, new_member, page)
    if @contribution and member
      @contribution.end_column = @end_column
      link_member_to_contribution(member)
    end
    if @end_column.empty?
      @contribution = HansardContribution.new("#{page.url}\##{@last_link}", @start_column)
    else
      @contribution = HansardContribution.new("#{page.url}\##{@last_link}", @end_column)
    end
    
    if new_member
      @member = resolve_member_name(new_member)
    end
  end
  
  def link_member_to_contribution(member)
    unless @members.keys.include?(member.search_name)
      if @component_members.keys.include?(member.search_name)
        @members[member.search_name] = @component_members[member.search_name]
      else
        @members[member.search_name] = member
        @component_members[member.search_name] = member
      end
    end
    @members[member.search_name].contributions << @contribution
  end
  
  def resolve_member_name(new_member)
    if @members.keys.include?(new_member.search_name)
      new_member = @members[new_member.search_name]
    elsif @component_members.keys.include?(new_member.search_name)
      new_member = @component_members[new_member.search_name]
    else
      @members[new_member.search_name] = new_member
      @component_members[new_member.search_name] = new_member
    end
    @member = new_member
  end
  
  def sanitize_text(text)
    text.force_encoding("utf-8")
    # text = text.gsub("\342\200\177", "'")
    # text = text.gsub("\342\200\230", "'")
    # text = text.gsub("\342\200\231", "'")
    text = text.gsub("’", "'")
    text = text.gsub("‘", "'")
    text = text.gsub("“", '"')
    text = text.gsub("”", '"')
    text = text.gsub("—", " - ")
    # text = text.gsub("\302\243", "£")
    text
  end
  
  def  html_fix(text)
    text = text.gsub("\n", " ")
    text = text.squeeze(" ")
    text = text.gsub("&quot;", '"')
    text = text.gsub("&amp;", "&")
    
    text.scan(/&lt;([^\s&]*)([^&]*)&gt;/).uniq.each do |match|
      text = text.gsub("&lt;#{match[0]}#{match[1]}&gt;", "<#{match[0]}#{match[1]}>")
    end
    text
  end
end