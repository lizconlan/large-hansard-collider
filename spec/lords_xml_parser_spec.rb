#encoding: utf-8

require './spec/rspec_helper.rb'
require './lib/lords/debates_xml_parser'

describe LordsDebatesXMLParser do
  before(:each) do
    NonContributionPara.any_instance.stubs(:save)
    ContributionPara.any_instance.stubs(:save)
    Component.any_instance.stubs(:save)
    DailyPart.any_instance.stubs(:save)
    Debate.any_instance.stubs(:save)
    Question.any_instance.stubs(:save)
    LordsDebatesXMLParser.any_instance.stubs(:house=)
  end
  
  def stub_part(house, date, part, volume)
    @daily_part = DailyPart.new
    DailyPart.stubs(:find_or_create_by).returns(@daily_part)
    @daily_part.expects(:house=).at_least_once.with(house)
    @daily_part.expects(:date=).at_least_once.with(date)
    if part
      @daily_part.expects(:part=).at_least_once.with(part)
    end
    @daily_part.stubs(:persisted?)
    @daily_part.stubs(:ident)
    @daily_part.expects(:volume=).at_least_once.with(volume)
    @daily_part.stubs(:save)
    @daily_part.stubs(:components).returns([])
  end
  
  context "when given a day's worth of debates that uses a single heading type" do
    before(:each) do
      @component = Component.new
      # @component.stubs(:sections).returns([])
      # @component.stubs(:ident).returns("2099-01-01_hansard_l_d")
      
     response = mock("Response")
     response.stubs(:body).returns(%Q|<html><head><meta name="Source" content="House of Lords Hansard, Volume: 752, Part: 119 "></head></html>|)
      RestClient.expects(:get).returns(response)
      
      data = File.read("./spec/data/lords/debates/simple-debates.xml")
      Dir.expects(:"[]").returns(["./xml/lords/debates/daylord2009-01-01a.xml"])
      File.expects(:read).with("./xml/lords/debates/daylord2009-01-01a.xml").returns(data)
      @parser = LordsDebatesXMLParser.new("2099-01-01")
      stub_part("lords", "2099-01-01", "119", "752")
    end
    
    it "should create a Debate for each heading" do
      debate = Debate.new
      Component.expects(:find_or_create_by).returns(@component)
      Debate.expects(:find_or_create_by).times(3).returns(debate)
      @parser.parse
    end
  end
end