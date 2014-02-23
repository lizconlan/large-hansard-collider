#encoding: utf-8

require 'nokogiri'
require 'rest-client'

class HansardPage
  attr_reader :html, :doc, :url, :next_url, :start_column, :end_column, :volume, :part, :title
  
  def initialize(url)
    @url = url
    @volume = ""
    @part = ""
    @title = ""
    response = RestClient.get(url)
    @html = response.body
    @doc = Nokogiri::HTML(@html)
    next_link = []
    if @doc.xpath("//div[@class='navLinks']").empty?
      next_link = @doc.xpath("//table").last.xpath("tr/td/a[text()='Next Section']")
    elsif @doc.xpath("//div[@class='navLinks'][2]").empty?
      next_link = @doc.xpath("//div[@class='navLinks'][1]/div[@class='navLeft']/a")
    else
      next_link = @doc.xpath("//div[@class='navLinks'][2]/div[@class='navLeft']/a")
    end
    unless next_link.empty?
      prefix = url[0..url.rindex("/")]
      @next_url = prefix + next_link.attr("href").value.to_s
    else
      @next_url = nil
    end
    scrape_metadata()
  end
  
  def get_content
    content = doc.xpath("//div[@id='content-small']")
    if content.empty?
      content = doc.xpath("//div[@id='maincontent1']")
    elsif content.children.size < 10
      content = doc.xpath("//div[@id='content-small']/table/tr/td[1]")
    end
    content
  end
  
  def self.component_link_xpath(house)
    if house.downcase == "commons"
      "//ul[@class='publications']/li/a"
    else
      "//ul[@class='event-list']/li/h3/a"
    end
  end
  
  def self.get_starting_link(doc, house, start_url)
    if house.downcase == "commons"
      rel_link = doc.xpath("string(//div[@id='content-small']/p[3]/a/@href)")
      if rel_link.empty?
        rel_link = doc.xpath("string(//div[@id='content-small']/table/tr/td[1]/p[3]/a[1]/@href)")
      end
      if rel_link.empty?
        #petitions / ministerial corrections
        rel_link = doc.xpath("string(//div[@id='content-small']/h1/a[1]/@href)")
      end
      if rel_link.empty?
        #slightly broken ministerial corrections
        rel_link = doc.xpath("string(//div[@id='content-small']/h3[2]/a[1]/@href)")
      end
      if rel_link.empty?
        rel_link = doc.xpath("string(//div[@id='maincontent1']/div/a[1]/@href)")
      end
      "http://www.publications.parliament.uk#{rel_link[0..rel_link.rindex("#")-1]}"
    else
      anchor_name = start_url.split("#").last
      anchor_test = anchor_name.empty? ? "" : "='#{anchor_name}'"
      doc.xpath("string(//a[@name#{anchor_test}][1]/following-sibling::*[1]/a[@href][1]/@href)")
    end
  end
  
  private
    def scrape_metadata
      subject = doc.xpath("//meta[@name='Subject']").attr("content").value.to_s
      @volume = subject[subject.index("Volume:")+8..subject.rindex(",")-1]
      @part = subject[subject.index("Part:")+5..subject.length].gsub("\302\240", "").strip
      @title = doc.xpath("//head/title").text.strip
    end
end

class PageFragment
  attr_accessor :text, :speaker, :column, :desc, :contribution_seq, :printed_name, :link, :overview, :summary, :ayes, :noes, :tellers_ayes, :tellers_noes, :number, :timestamp, :content
end