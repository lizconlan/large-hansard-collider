# encoding: UTF-8

require './spec/rspec_helper.rb'
require './lib/commons/ministerial_corrections_parser'

describe MinisterialCorrectionsParser do
  def stub_saves
    Preamble.any_instance.stubs(:save)
    NonContributionPara.any_instance.stubs(:save)
    ContributionPara.any_instance.stubs(:save)
    ContributionTable.any_instance.stubs(:save)
    Component.any_instance.stubs(:save)
    DailyPart.any_instance.stubs(:save)
    MinisterialCorrection.any_instance.stubs(:save)
  end
  
  def stub_daily_part
    @daily_part = DailyPart.new()
    DailyPart.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c").returns(@daily_part)
  end
  
  def stub_page(file, mock_html=nil)
    if mock_html
      html = mock_html
    else
      html = File.read(file)
    end
    HansardPage.any_instance.stubs(:scrape_metadata)
    HansardPage.any_instance.stubs(:volume).returns("531")
    HansardPage.any_instance.stubs(:part).returns("190")
    HansardPage.any_instance.stubs(:next_url).returns(nil)
    mock_response = mock("response")
    mock_response.expects(:body).at_least_once.returns(html)
    RestClient.expects(:get).at_least_once.returns(mock_response)
    @page = HansardPage.new(@url)
  end
  
  context "when given a single Ministerial Correction" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/cm201314/cmhansrd/cm140116/corrtext/140116c0001.htm"
      stub_saves
      stub_daily_part
      
      @parser = MinisterialCorrectionsParser.new("2099-01-01")
      @parser.stubs(:component_prefix).returns("mc")
      @parser.expects(:link_to_first_page).returns(@url)
      
      stub_page("spec/data/commons/ministerial_correction.html")
      HansardPage.expects(:new).returns(@page)
      
      @component = Component.new(:ident => '2099-01-01_hansard_c_mc')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_mc').returns(@component)
    end
    
    it "should create the Preamble and a MinisterialCorrection" do
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).at_least_once.returns(ncpara)
      Preamble.any_instance.stubs(:title=)
      Preamble.expects(:find_or_create_by).returns(Preamble.new)
      correction = MinisterialCorrection.new
      
      MinisterialCorrection.expects(:find_or_create_by).returns(correction)
      
      @parser.parse
    end
    
    it "should set the title and department info correctly" do
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).at_least_once.returns(ncpara)
      
      preamble = Preamble.new
      Preamble.expects(:find_or_create_by).returns(preamble)
      preamble.expects(:title=).with("Ministerial Correction")
      preamble.expects(:paragraphs).at_least_once.returns([ncpara])
      
      correction = MinisterialCorrection.new
      MinisterialCorrection.expects(:find_or_create_by).returns(correction)
      correction.expects(:title=).with("Correction - Syria")
      correction.expects(:department=).with("Foreign and Commonwealth Office")
      
      @parser.parse
    end
  end
  
  context "when given the Preamble and 2 Ministerial Corrections" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/cm201314/cmhansrd/cm130701/corrtext/130701c0001.htm"
      stub_saves
      stub_daily_part
      
      @parser = MinisterialCorrectionsParser.new("2099-01-01")
      @parser.stubs(:component_prefix).returns("mc")
      @parser.expects(:link_to_first_page).returns(@url)
      
      stub_page("spec/data/commons/ministerial_corrections.html")
      HansardPage.expects(:new).returns(@page)
      
      @component = Component.new(:ident => '2099-01-01_hansard_c_mc')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_mc').returns(@component)
    end
    
    it "should create 2 MinisterialCorrections" do
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).at_least_once.returns(ncpara)
      
      preamble = Preamble.new
      Preamble.expects(:find_or_create_by).returns(preamble)
      preamble.expects(:title=)
      
      correction = MinisterialCorrection.new
      MinisterialCorrection.expects(:find_or_create_by).times(2).returns(correction)
      
      @parser.parse
    end
    
    it "should set the title and department info correctly" do
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).at_least_once.returns(ncpara)
      
      preamble = Preamble.new
      Preamble.expects(:find_or_create_by).returns(preamble)
      preamble.expects(:title=).with("Ministerial Corrections")
      
      correction = MinisterialCorrection.new(ident: "2099-01-01_hansard_c_mc_000002")
      MinisterialCorrection.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_mc_000002").returns(correction)
      correction.expects(:title=).with("Correction - RSPCA")
      correction.expects(:department=).with("Justice")
      correction.expects(:component=).with(@component)
      
      correction = MinisterialCorrection.new(ident: "2099-01-01_hansard_c_mc_000003")
      MinisterialCorrection.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_mc_000003").returns(correction)
      correction.expects(:title=).with("Correction - Members: Correspondence")
      correction.expects(:department=).with("Transport")
      correction.expects(:component=).with(@component)
      
      @parser.parse
    end
  end
end
