#encoding: utf-8

require 'rest-client'
require 'nokogiri'
require 'date'

require './models/hansard_page'
require './models/hansard_member'

require './models/daily_part'
require './models/component'
require './models/section'
require './models/paragraph'

require 'state_machine'

class Parser
  attr_reader :date, :doc_id, :house, :state
  
  state_machine :state, :initial => :idle do
    before_transition [:starting, :heading_complete, :parsing_section, :parsing_subsection] => :parsing_section, :do => :save_section
    before_transition all - [:idle, :finished] => :setting_heading, :do => :save_section
    before_transition all - :idle => :finished, :do => :save_section
    before_transition [:parsing_section, :parsing_subsection] => :parsing_subsection, :do => :save_section
    
    event :start do
      transition :idle => :starting
    end
    
    event :set_new_heading do
      transition all - [:idle, :finished] => :setting_heading
    end
    
    event :stop_new_heading do
      transition :setting_heading => :heading_complete
    end
    
    event :start_new_section do
      transition all - [:idle, :finished] => :parsing_section
    end
    
    event :start_subsection do
      transition [:starting, :parsing_section] => :parsing_subsection
    end
    
    event :finish do
      transition all => :finished
    end
    
    state :idle
    state :starting
    state :setting_heading
    state :heading_complete
    state :parsing_section
    state :parsing_subsection
    state :finished
  end
  
  def initialize(date, house)
    @date = date
    @house = house
    @doc_ident = "#{date}_hansard_#{house[0..0].downcase()}"
    
    @daily_part = nil 
    @hansard_component = nil
    @page = nil
    @component_ident = ""
    @start_url = ""
    @section = nil
    super()
  end
  
  def init_vars
    @component_seq = 0
    @section_seq = 0
    @para_seq = 0
    
    @members = {}
    @member = nil
    
    @last_link = ""
    @subject = ""
    @column = ""
  end
  
  def get_component_index(component_name)
    url = get_component_links[component_name]
    if url
      @start_url = url
      return get_page(url)
    end
  end
  
  def get_component_links
    parse_date = Date.parse(date)
    index_page = "http://www.parliament.uk/business/publications/hansard/#{house.downcase}/by-date/?d=#{parse_date.day}&m=#{parse_date.month}&y=#{parse_date.year}"
    urls = {}
    
    html = get_page(index_page)
    if html
      doc = Nokogiri::HTML(html)
      doc.xpath(HansardPage.component_link_xpath(house)).each do |link|
        urls["#{link.text.strip}"] = link.attribute("href").value.to_s
      end
    end
    urls
  end
  
  def link_to_first_page
    unless self.respond_to?(:component_name)
      component_name = 0
    end
    html = get_component_index
    return nil unless html
    
    doc = Nokogiri::HTML(html)
    HansardPage.get_starting_link(doc, house, @start_url)
  end
  
  def parse
    start
    init_vars
    first_page = link_to_first_page
    
    unless first_page
      if self.respond_to?(:component_name)
        component = self.component_name
      else
        component = ""
      end
      warn "No #{component} data available for #{Date.parse(date).strftime("%e %b %Y")}".squeeze(' ')
    else
      @page = HansardPage.new(first_page)
      
      @daily_part = DailyPart.find_or_create_by(ident: @doc_ident)
      @daily_part.house = house
      @daily_part.date = date
      @daily_part.volume = @page.volume
      @daily_part.part = @page.part
      create_component
      
      parse_page
      
      while @page.next_url
        @page = HansardPage.new(@page.next_url)
        parse_page
      end
    end
    finish
  end
  
  
  private
  
  def parse_page(page = @page)
    content = page.get_content
    content.children.each do |child|
      if child.class == Nokogiri::XML::Element
        parse_node(child)
      end
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
  
  def create_component
    if !defined?(component_prefix) or component_prefix.empty?
      component_ident = @doc_ident
    else
      component_ident = "#{@doc_ident}_#{component_prefix}"
    end
    
    @hansard_component = Component.find_or_create_by(ident: component_ident)
    @hansard_component.url = @start_url
    @section_seq = 0
    @hansard_component.daily_part = @daily_part
    
    @hansard_component.sequence = get_sequence(@component_name)
    
    @daily_part.components << @hansard_component
    @daily_part.save
    
    @hansard_component.name = @component_name
    @hansard_component.save
  end
  
  def get_sequence(component_name)
  end
  
  def determine_fragment_type(node)
    case node.attr("name")
    when /^hd_/
      #heading e.g. the date, The House met at..., The Deputy PM was asked
      @page_fragment_type = "heading"
      @link = node.attr("name")
    when /^place_/
      @page_fragment_type = "location heading"
      @link = node.attr("name")
    when /^dpthd_/
      @page_fragment_type = "department heading"
      @link = node.attr("name")
    when /^subhd_/
      @page_fragment_type = "subject heading"
      @link = node.attr("name")
    when /^qn_/
      @page_fragment_type = "question"
      @link = node.attr("name")
    when /^st_/
      @page_fragment_type = "contribution"
      @link = node.attr("name")
    when /^divlst_/
      @page_fragment_type = "division"
      @link = node.attr("name")
    end 
  end
  
  def handle_member_info(member, new_member, seq=nil)
    if member
      add_member_to_temp_store(member)
    end
    
    if new_member
      @member = resolve_member_name(new_member)
    end
  end
  
  def add_member_to_temp_store(member)
    unless @members.keys.include?(member.search_name)
      @members[member.search_name] = member
    end
  end
  
  def resolve_member_name(new_member)
    if @members.keys.include?(new_member.search_name)
      new_member = @members[new_member.search_name]
    else
      @members[new_member.search_name] = new_member
    end
    @member = new_member
  end
  
  def sanitize_text(text)
    text.force_encoding("utf-8")
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
  
  def process_timestamp(text)
    return false unless @section
    
    @para_seq +=1
    ts_ident = "#{@section.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
    timestamp = Timestamp.find_or_create_by(ident: ts_ident)
    timestamp.content = text
    timestamp.column = @column
    timestamp.url = "#{@page.url}\##{@last_link}"
    timestamp.section = @section
    timestamp.sequence = @para_seq
    timestamp.save
    
    @section.paragraphs << timestamp
  end
  
  def setup_preamble(title)
    @section_seq += 1
    section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    @section = Preamble.find_or_create_by(ident: section_ident)
    @section.title = title
    @section.url = "#{@page.url}/##{@last_link}"
    @section.sequence = @section_seq
    @section.component = @hansard_component
    @section.columns = []
    @para_seq = 0
  end
  
  def create_new_contribution_para(text, member_name="", ident=nil)
    stored_name = ""
    unless ident
      @para_seq += 1
      ident = "#{@section.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
    end
    para = ContributionPara.find_or_create_by(ident: ident)
    para.content = text
    
    if text.strip =~ /^#{@member.post} \(#{@member.name}\)/
      para.speaker_printed_name = "#{@member.post} (#{@member.name})"
    elsif text.strip =~  /^#{@member.name} \(#{@member.constituency}\)/
      para.speaker_printed_name = @member.printed_name
    elsif member_name != ""
      para.speaker_printed_name = member_name.split("(").first.gsub(":", "").strip
    end
    if @member.index_name.split(" ").size < 2
      stored_name = para.member = @member.printed_name
    else
      stored_name = para.member = @member.index_name
    end
    add_member_to_temp_store(@member)
    
    para.sequence = @para_seq
    para.section = @section
    para.column = @column
    para.url = "#{@page.url}\##{@last_link}"
    para.save
    
    @section.paragraphs << para
    if @section.members.nil?
      @section.members = [stored_name]
    else
      @section.members << stored_name unless @section.members.include?(stored_name)
    end
    @section.append_column(@column)
    
    para
  end
  
  def create_new_noncontribution_para(text, ident=nil)
    unless ident
      @para_seq += 1
      ident = "#{@section.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
    end
    
    para = NonContributionPara.find_or_create_by(ident: ident)
    para.content = text
    para.sequence = @para_seq
    para.section = @section
    para.column = @column
    para.url = "#{@page.url}\##{@last_link}"
    para.save
    @section.paragraphs << para
    @section.append_column(@column)
    para
  end
  
  def debug()
    unless ENV["RACK_ENV"] == "test"
      p ""
      p "Type: #{@section.type}"
      p "title: #{@section.title ? @section.title : "nil"}"
      p "ident: #{@section.ident ? @section.ident : "nil"}"
      p "url: #{@section.url ? @section.url : "nil"}"
      p "****"
    end
  end
end