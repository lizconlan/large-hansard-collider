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
      
     response = mock("Response")
     response.stubs(:body).returns(%Q|<html><head><meta name="Source" content="House of Lords Hansard, Volume: 752, Part: 119 "></head></html>|)
      RestClient.expects(:get).returns(response)
      
      data = File.read("./spec/data/lords/debates/simple-debates.xml")
      Dir.expects(:"[]").returns(["./xml/lords/debates/daylord2009-01-01a.xml"])
      File.expects(:read).with("./xml/lords/debates/daylord2009-01-01a.xml").returns(data)
      @parser = LordsDebatesXMLParser.new("2099-01-01")
      stub_part("lords", "2099-01-01", "119", "752")
      Component.expects(:find_or_create_by).returns(@component)
    end
    
    it "should create a Debate or Question for each heading" do
      debate = Debate.new
      question = Question.new
      Debate.expects(:find_or_create_by).times(2).returns(debate)
      Question.expects(:find_or_create_by).returns(question)
      @parser.parse
    end
    
    it "should assign the correct title to each section" do
      debate = Debate.new
      question = Question.new
      
      Debate.expects(:find_or_create_by).returns(debate)
      debate.expects(:title=).with("Introduction: The Lord Bishop of Durham")
      
      Debate.expects(:find_or_create_by).returns(debate)
      debate.expects(:title=).with("Reading Clerk — Appointment of Simon Peter Burton")
      
      Question.expects(:find_or_create_by).returns(question)
      question.expects(:title=).with("Scottish Independence: Faslane — Question")
      @parser.parse
    end
    
    it "should assign the expected number of paragraphs to each section" do
      debate = Debate.new
      question = Question.new
      
      Debate.expects(:find_or_create_by).returns(debate)
      debate.paragraphs.expects(:<<).times(1)
      
      Debate.expects(:find_or_create_by).returns(debate)
      debate.paragraphs.expects(:<<).times(22)
      
      Question.expects(:find_or_create_by).returns(question)
      question.paragraphs.expects(:<<).times(16)
      @parser.parse
    end
    
    it "should set the member info correctly" do
      debate1 = Debate.new
      debate2 = Debate.new
      question = Question.new
      
      Debate.expects(:find_or_create_by).with(ident: "_000001").returns(debate1)
      Debate.expects(:find_or_create_by).with(ident: "_000002").returns(debate2)
      Question.expects(:find_or_create_by).returns(question)
      @parser.parse
      
      debate1.members.should eq []
      debate2.members.should eq ["Baroness D'Souza", "Lord Hill of Oareford", "Baroness Royall of Blaisdon", "Lord Wallace of Tankerness", "Lord Laming", "The Lord Bishop of Chester"]
      question.members.should eq ["Lord Forsyth of Drumlean", "Lord Astor of Hever", "Lord Wigley", "Lord Boyce", "Lord Palmer of Childs Hill", "Lord West of Spithead", "Lord Selkirk of Douglas"]
    end
    
    it "should set the column info correctly" do
      debate1 = Debate.new
      debate2 = Debate.new
      question = Question.new
      
      Debate.expects(:find_or_create_by).with(ident: "_000001").returns(debate1)
      Debate.expects(:find_or_create_by).with(ident: "_000002").returns(debate2)
      Question.expects(:find_or_create_by).returns(question)
      @parser.parse
      
      debate1.columns.should eq ["1095"]
      debate2.columns.should eq ["1095", "1097"]
      question.columns.should eq ["1097", "1099"]
    end
  end
end