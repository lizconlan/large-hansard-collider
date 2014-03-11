#encoding: utf-8

require 'date'
require 'nokogiri'
require 'rest-client'
require 'state_machine'

class XMLParser
  attr_reader :source, :doc, :part, :volume, :state
  
  state_machine :state, :initial => :idle do
    before_transition [:starting, :parsing_section, :parsing_subsection] => :parsing_section, :do => :save_section
    before_transition all - :idle => :finished, :do => :save_section
    before_transition [:parsing_section, :parsing_subsection] => :parsing_subsection, :do => :save_section
    
    event :start do
      transition :idle => :starting
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
    state :parsing_section
    state :parsing_subsection
    state :finished
  end
  
  def initialize(date, file_prefix, file_path)
    @date = date
    @part = nil
    @volume = nil
    file_pattern = "#{file_prefix}#{date}*"
    files = Dir["#{file_path}/#{file_pattern}*".squeeze("/")]
    if self.respond_to?(:component_name)
      component = self.component_name
    else
      component = ""
    end
    if files.empty?
      warn "No #{house} #{component} data available for #{Date.parse(date).strftime("%e %b %Y")}".squeeze(' ')
    else
      @source = files.sort.last
      @doc = Nokogiri::XML(File.read(@source))
    end
    super()
  end
  
  
  private
  
  def strip_text(text)
    text.gsub("\n", " ").gsub("\t", " ").squeeze(" ").strip
  end
  
  def scrape_metadata(url)
    response = RestClient.get(url)
    html = response.body
    doc = Nokogiri::HTML(html)
    
    subject = doc.xpath("//meta[@name='Source']").attr("content").value.to_s
    unless subject.include?("Volume")
      subject = doc.xpath("//meta[@name='Subject']").attr("content").value.to_s
    end
    @volume = subject[subject.index("Volume:")+8..subject.rindex(",")-1]
    @part = subject[subject.index("Part:")+5..subject.length].gsub("\302\240", "").strip
  end
end