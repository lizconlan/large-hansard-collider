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
      tables = @doc.xpath("//table")
      if tables.last
        next_link = tables.last.xpath("tr/td/a[text()='Next Section']")
      else
        next_link = ""
      end
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
      content = doc.xpath("//div[@id='maincontent']") #2006
    end
    if content.empty?
      content = doc.xpath("//div[@id='maincontent1']")
      if content.empty?
        # at this point we're assuming that the template isn't loaded, see
        # http://www.publications.parliament.uk/pa/cm200910/cmhansrd/cm100204/text/100204w0001.htm
        content = doc.xpath("//body")
      end
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
      rel_link = doc.xpath("//div[@id='content-small']//a[contains(@href,'.htm')]/@href")[0].to_s
      if rel_link.empty?
        rel_link = doc.xpath("//div[@id='maincontent']//a[contains(@href,'.htm')]/@href")[0].to_s
      end
      if rel_link.empty?
        rel_link = doc.xpath("//div[@id='maincontent1']//a[contains(@href,'.htm')]/@href")[0].to_s
      end
      if rel_link.empty? or rel_link =~ /^http/
        #to deal with a glitch on http://www.publications.parliament.uk/pa/cm200910/cmhansrd/cm100127/debindx/100127-x.htm
        rel_link = doc.xpath("//div[@id='maincontent1']//div[@id='maincontent1']//a[contains(@href,'.htm')]/@href")[0].to_s
        if rel_link.empty? or rel_link =~ /^http/
          #argh - http://www.publications.parliament.uk/pa/cm200809/cmhansrd/cm090226/index/90226-x.htm
          rel_link = doc.xpath("//div[@id='maincontent1']//div[@id='maincontent1']//div[@id='maincontent1']//a[contains(@href,'.htm')]/@href")[0].to_s
        end
      end
      if rel_link.empty?
        #...and the opposite problem with http://www.publications.parliament.uk/pa/cm200910/cmhansrd/cm100204/index/100204-x.htm
        rel_link = doc.xpath("//a[contains(@href,'.htm')]/@href")[0].to_s
      end
      # correct a petition link if it goes to written answers
      # (no, really - see http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm100726/petnindx/100726-x.htm)
      if start_url =~ /petnindx/ and rel_link =~ /(.*)\/text\/(\d+)w(.*)/
        rel_link = "#{$1}/petntext/#{$2}p0001.htm\#fake"
      end
      rel_link.gsub!("\n", "")
      if rel_link[0..2] == "../"
        url_parts = start_url.split("/")
        url_parts.pop #dump the filename
        url_parts.pop #go up one level
        "#{url_parts.join("/")}#{rel_link[2..rel_link.rindex("#")-1]}"
      else
        "http://www.publications.parliament.uk#{rel_link[0..rel_link.rindex("#")-1]}"
      end
    else
      anchor_name = start_url.split("#").last
      anchor_test = anchor_name.empty? ? "" : "='#{anchor_name}'"
      doc.xpath("string(//a[@name#{anchor_test}][1]/following-sibling::*[1]/a[@href][1]/@href)")
    end
  end
  
  private
    def scrape_metadata
      subject = doc.xpath("//meta[@name='Subject']").attr("content").value.to_s
      unless subject.include?("Volume")
        subject = doc.xpath("//meta[@name='Source']").attr("content").value.to_s
      end
      @volume = subject[subject.index("Volume:")+8..subject.rindex(",")-1]
      @part = subject[subject.index("Part:")+5..subject.length].gsub("\302\240", "").strip
      @title = doc.xpath("//head/title").text.strip
    end
end

class PageFragment
  attr_accessor :text, :speaker, :column, :desc, :contribution_seq, :printed_name, :link, :overview, :summary, :ayes, :noes, :tellers_ayes, :tellers_noes, :number, :timestamp, :content
end