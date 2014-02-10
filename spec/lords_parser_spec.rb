require './spec/rspec_helper.rb'
require './lib/lords/parser'

describe LordsParser do
  before(:all) do
    @daily_part = DailyPart.new
    
    @parser = LordsParser.new("2099-01-01")
    @parser.init_vars()
  end
  
  context "in general" do
    before(:all) do
      @html = File.read("./spec/data/lords_by_date.html")
      @component_list = {
        "Debates and Oral Answers" => "http://www.publications.parliament.uk/pa/ld201011/ldhansrd/index/110117.html",
        "Grand Committee" => "http://www.publications.parliament.uk/pa/ld201011/ldhansrd/index/110117.html#start_grand",
        "Written Statements" => "http://www.publications.parliament.uk/pa/ld201011/ldhansrd/index/110117.html#start_minist",
        "Written Answers" => "http://www.publications.parliament.uk/pa/ld201011/ldhansrd/index/110117.html#start_written"
      }
    end
    
    it "should retrieve an unordered Hash of component names and urls" do
      index_url = "http://www.parliament.uk/business/publications/hansard/lords/by-date/?d=1&m=1&y=2099"
      response = mock()
      response.expects(:body).returns(@html)
      RestClient.expects(:get).with(index_url).returns(response)
      
      @parser.get_component_links.should == @component_list
    end
    
    it "should load a component page for a given component name" do
      response = mock()
      response.expects("body").returns("html goes here")
      @parser.expects(:get_component_links).returns(@component_list)
      url = "http://www.publications.parliament.uk/pa/ld201011/ldhansrd/index/110117.html#start_grand"
      RestClient.expects(:get).with(url).returns(response)
      @parser.get_component_index("Grand Committee").should eq "html goes here"
    end
  end
  
  context "when dealing with index pages" do
    before(:all) do
      @_html = File.read("./spec/data/lords/index_jan_2011.html")
    end
    
    it "should work out the link to the first content page" do
      url = "http://www.publications.parliament.uk/pa/ld201011/ldhansrd/text/110117-gc0001.htm#11011725000111"
      @parser.expects(:get_component_index).returns(@_html)
      
      @parser.link_to_first_page.should eq url
    end
  end
end