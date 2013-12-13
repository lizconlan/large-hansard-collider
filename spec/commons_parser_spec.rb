require './spec/rspec_helper.rb'
require './lib/commons/parser'

describe CommonsParser do
  before(:all) do
    daily_part = DailyPart.new
    DailyPart.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c").returns(daily_part)
    
    @parser = CommonsParser.new("2099-01-01")
    @parser.init_vars()
  end
  
  context "in general" do
    before(:all) do
      @html = File.read("./spec/data/commons_by_date.html")
      @component_list = {
        "Debates and Oral Answers"=>"http://www.publications.parliament.uk/pa/cm201314/cmhansrd/cm130913/debindx/130913-x.htm",
        "Written Statements"=>"http://www.publications.parliament.uk/pa/cm201314/cmhansrd/cm130913/wmsindx/130913-x.htm",
        "Written Answers"=>"http://www.publications.parliament.uk/pa/cm201314/cmhansrd/cm130913/index/130913-x.htm",
        "Petitions"=>"http://www.publications.parliament.uk/pa/cm201314/cmhansrd/cm130913/petnindx/130913-x.htm",
        "Ministerial Corrections"=>"http://www.publications.parliament.uk/pa/cm201314/cmhansrd/cm130913/corrindx/130913-x.htm"
      }
    end
    
    it "should retrieve an unordered Hash of component names and urls" do
      index_url = "http://www.parliament.uk/business/publications/hansard/commons/by-date/?d=1&m=1&y=2099"
      response = mock()
      response.expects(:body).returns(@html)
      RestClient.expects(:get).with(index_url).returns(response)
          
      @parser.get_component_links.should == @component_list
    end
    
    it "should load a component page for a given component name" do
      response = mock()
      response.expects("body").returns("html goes here")
      @parser.expects(:get_component_links).returns(@component_list)
      url = "http://www.publications.parliament.uk/pa/cm201314/cmhansrd/cm130913/wmsindx/130913-x.htm"
      RestClient.expects(:get).with(url).returns(response)
      @parser.get_component_index("Written Statements").should eq "html goes here"
    end
    
    context "when dealing with pages that use the maincontent1 format (up to Feb 17 2011)" do
      before(:all) do
        @component_html = File.read("./spec/data/commons/wms_index_jan_2011.html")
      end
      
      it "should work out the link to the first content page for a given component when the maincontent1 format is used" do
        component = "Written Statements"
        url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/wmstext/110110m0001.htm"
        @parser.expects(:get_component_index).returns(@component_html)
        
        @parser.link_to_first_page.should eq url
      end
    end
    
    context "when dealing with pages that use the content-small id (Feb 28 2011 onwards)" do
      before(:all) do
        @component_html = File.read("./spec/data/commons/wms_index_nov_2011.html")
      end
      
      it "should work out the link to the first content page for a given component" do
        component = "Written Statements"
        url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm111121/wmstext/111121m0001.htm"
        @parser.expects(:get_component_index).returns(@component_html)
        
        @parser.link_to_first_page.should eq url
      end
      
      it "should be able to find the content when asked to parse the page" do
        url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
        @hansard_page = HansardPage.new(url)
        page_html = %Q|<html><head>
          <meta name="Subject" content="House of Commons Hansard, Volume: 523, Part: 121">
          <meta name="Columns" content="Columns: 91WS to 96WS"></head>
          <body><div id="content-small"><table><tr><td><div>content goes here</div></td></tr></table></div></body></html>|
        
        @hansard_page.expects(:doc).times(2).returns(Nokogiri::HTML(page_html))      
        @parser.expects(:parse_node)
        
        @parser.parse_page(@hansard_page)
      end
      
      context "when no data is found" do
        it "should report that no component data is found" do
          daily_part = DailyPart.new
          @parser.expects(:link_to_first_page).returns(nil)
          $stderr.expects(:write).with("No data available for this date")
          $stderr.expects(:write).with("\n")
          
          @parser.parse_pages
        end
      end
    end
  end
end