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
      stub_part("lords", "2099-01-01", "119", "752")
      Component.expects(:find_or_create_by).returns(@component)
    end
    
    context "and there are only major headings" do
      before(:each) do
        data = File.read("./spec/data/lords/debates/simple-debates.xml")
        Dir.expects(:"[]").returns(["./xml/lords/debates/daylord2009-01-01a.xml"])
        File.expects(:read).with("./xml/lords/debates/daylord2009-01-01a.xml").returns(data)
        @parser = LordsDebatesXMLParser.new("2099-01-01")
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
        debate1 = Debate.new
        debate1.stubs(:paragraphs).returns(["fake para"])
        debate2 = Debate.new
        debate2.stubs(:paragraphs).returns(["fake para"])
        question = Question.new
        
        Debate.expects(:find_or_create_by).with(ident: "_000001").returns(debate1)
        debate1.paragraphs.expects(:<<).times(1)
        
        Debate.expects(:find_or_create_by).with(ident: "_000002").returns(debate2)
        debate2.paragraphs.expects(:<<).times(22)
        
        Question.expects(:find_or_create_by).with(ident: "_000003").returns(question)
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
    
    context "and there are only minor headings" do
      before(:each) do
        data = File.read("./spec/data/lords/debates/minor-headings-only.xml")
        Dir.expects(:"[]").returns(["./xml/lords/debates/daylord2009-01-01a.xml"])
        File.expects(:read).with("./xml/lords/debates/daylord2009-01-01a.xml").returns(data)
        @parser = LordsDebatesXMLParser.new("2099-01-01")
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
    end
  end
  
  context "when dealing with a Bill debate" do
    before(:each) do
      @component = Component.new
      
      response = mock("Response")
      response.stubs(:body).returns(%Q|<html><head><meta name="Source" content="House of Lords Hansard, Volume: 752, Part: 119 "></head></html>|)
      RestClient.expects(:get).returns(response)
      
      data = File.read("./spec/data/lords/debates/bill-debate.xml")
      Dir.expects(:"[]").returns(["./xml/lords/debates/daylord2009-01-01a.xml"])
      File.expects(:read).with("./xml/lords/debates/daylord2009-01-01a.xml").returns(data)
      @parser = LordsDebatesXMLParser.new("2099-01-01")
      stub_part("lords", "2099-01-01", "119", "752")
      Component.expects(:find_or_create_by).returns(@component)
    end
    
    it "should create a single Debate and assign it a title and a Bill Title" do
      debate = Debate.new(:title => "Pensions Bill")
      debate.expects(:title=).with("Pensions Bill")
      debate.expects(:title=).with("Pensions Bill — Report (1st Day)")
      debate.expects(:bill_title=).with("Pensions Bill")
      Debate.expects(:find_or_create_by).with(ident: "_000001").returns(debate)
      @parser.parse
    end
    
    it "should assign the expected number of paragraphs to the Debate" do
      debate = Debate.new
      Debate.expects(:find_or_create_by).with(ident: "_000001").returns(debate)
      debate.paragraphs.expects(:<<).times(10)
      @parser.parse
    end
  end
  
  context "when given a day's worth of debates that includes grouped amendments" do
    before(:each) do
      @component = Component.new
      
      response = mock("Response")
      response.stubs(:body).returns(%Q|<html><head><meta name="Source" content="House of Lords Hansard, Volume: 752, Part: 119 "></head></html>|)
      RestClient.expects(:get).returns(response)
      
      data = File.read("./spec/data/lords/debates/grouped-amendments.xml")
      Dir.expects(:"[]").returns(["./xml/lords/debates/daylord2009-01-01a.xml"])
      File.expects(:read).with("./xml/lords/debates/daylord2009-01-01a.xml").returns(data)
      @parser = LordsDebatesXMLParser.new("2099-01-01")
      stub_part("lords", "2099-01-01", "119", "752")
      Component.expects(:find_or_create_by).returns(@component)
    end
    
    it "should create a SectionGroup as a wrapper for the contained Debate" do
      container = SectionGroup.new
      debate1 = Debate.new(:ident => "_000001")
      debate1.expects(:ident=).with("_000002")
      debate = Debate.new
      Debate.expects(:find_or_create_by).with(ident: "_000001").returns(debate1)
      SectionGroup.expects(:find_or_create_by).with(ident: "_000001").returns(container)
      Debate.expects(:find_or_create_by).with(ident: "_000003").returns(debate)
      Debate.expects(:find_or_create_by).with(ident: "_000004").returns(debate)
      Debate.expects(:find_or_create_by).with(ident: "_000005").returns(debate)
      @parser.parse
      
      debate1.paragraphs.expects(:<<).times(0)
      debate.paragraphs.expects(:<<).times(0)
      debate1.parent_section_id.should eq container.id
      debate.parent_section_id.should eq container.id
    end
    
    it "should assign the title and expected number of paragraphs to the Debates" do
      container = SectionGroup.new
      debate1 = Debate.new(:ident => "_000001")
      debate1.expects(:ident=).with("_000002")
      debate2 = Debate.new
      debate3 = Debate.new
      debate4 = Debate.new
      Debate.expects(:find_or_create_by).with(ident: "_000001").returns(debate1)
      SectionGroup.expects(:find_or_create_by).with(ident: "_000001").returns(container)
      Debate.expects(:find_or_create_by).with(ident: "_000003").returns(debate2)
      Debate.expects(:find_or_create_by).with(ident: "_000004").returns(debate3)
      Debate.expects(:find_or_create_by).with(ident: "_000005").returns(debate4)
      
      debate1.expects(:title=).with("Industrial Training Levy (Engineering Construction Industry Training Board) Order 2014")
      debate2.expects(:title=).with("National Minimum Wage (Amendment) Regulations 2014")
      debate3.expects(:title=).with("National Minimum Wage (Variation of Financial Penalty) Regulations 2014")
      container.expects(:title=).with("Motions to Approve")
      container.paragraphs.expects(:<<).times(4)
      
      @parser.parse
    end
  end
  
  context "when given a day's worth of that includes grouped amendments" do
    before(:each) do
      @component = Component.new
      
      response = mock("Response")
      response.stubs(:body).returns(%Q|<html><head><meta name="Source" content="House of Lords Hansard, Volume: 752, Part: 119 "></head></html>|)
      RestClient.expects(:get).returns(response)
      
      data = File.read("./spec/data/lords/debates/grouped-amendments.xml")
      Dir.expects(:"[]").returns(["./xml/lords/debates/daylord2009-01-01a.xml"])
      File.expects(:read).with("./xml/lords/debates/daylord2009-01-01a.xml").returns(data)
      @parser = LordsDebatesXMLParser.new("2099-01-01")
      stub_part("lords", "2099-01-01", "119", "752")
      Component.expects(:find_or_create_by).returns(@component)
    end
    
    it "should create an SectionGroup as a wrapper for the contained Sections" do
      amendment1 = Debate.new(ident: "_000001", sequence: 1)
      amendment2 = Section.new(ident: "_000003", sequence: 3)
      amendment3 = Section.new(ident: "_000004", sequence: 4)
      unrelated = Section.new()
      wrapper =SectionGroup.new
      Debate.expects(:find_or_create_by).with(ident: "_000001").returns(amendment1)
      amendment1.expects(:ident=).with("_000002")
      amendment1.expects(:sequence=).with(1)
      amendment1.expects(:sequence=).with(2)
      SectionGroup.expects(:find_or_create_by).with(ident: "_000001").returns(wrapper)
      wrapper.expects(:sequence=).with(1)
      Debate.expects(:find_or_create_by).with(ident: "_000003").returns(amendment2)
      amendment2.expects(:sequence=).with(3)
      Debate.expects(:find_or_create_by).with(ident: "_000004").returns(amendment3)
      Debate.expects(:find_or_create_by).with(ident: "_000005").returns(unrelated)
      @parser.parse
    end
    
    it "should not include subsequent sections to the SectionGroup" do
      amendment1 = Debate.new(ident: "_000001", sequence: 1)
      amendment2 = Section.new(ident: "_000003", sequence: 3)
      amendment3 = Section.new(ident: "_000004", sequence: 4)
      unrelated = Section.new()
      wrapper = SectionGroup.new
      Debate.expects(:find_or_create_by).with(ident: "_000001").returns(amendment1)
      amendment1.expects(:ident=).with("_000002")
      SectionGroup.expects(:find_or_create_by).with(ident: "_000001").returns(wrapper)
      Debate.expects(:find_or_create_by).with(ident: "_000003").returns(amendment2)
      Debate.expects(:find_or_create_by).with(ident: "_000004").returns(amendment3)
      Debate.expects(:find_or_create_by).with(ident: "_000005").returns(unrelated)
      @parser.parse
      
      sections = wrapper.sections.to_a.should_not include("_000005")
      unrelated.parent_section.should be_nil
    end
    
    it "should assign the titles to the relevant Sections and expected number of paragraphs to the SectionGroup" do
      amendment1 = Debate.new(ident: "_000001", sequence: 1)
      amendment2 = Section.new(ident: "_000003", sequence: 3)
      amendment3 = Section.new(ident: "_000004", sequence: 4)
      unrelated = Section.new()
      wrapper = SectionGroup.new
      Debate.expects(:find_or_create_by).with(ident: "_000001").returns(amendment1)
      SectionGroup.expects(:find_or_create_by).with(ident: "_000001").returns(wrapper)
      Debate.expects(:find_or_create_by).with(ident: "_000003").returns(amendment2)
      Debate.expects(:find_or_create_by).with(ident: "_000004").returns(amendment3)
      Debate.expects(:find_or_create_by).with(ident: "_000005").returns(unrelated)
      
      wrapper.paragraphs.expects(:<<).times(4)
      amendment1.expects(:title=).with("Industrial Training Levy (Engineering Construction Industry Training Board) Order 2014")
      amendment2.expects(:title=).with("National Minimum Wage (Amendment) Regulations 2014")
      amendment3.expects(:title=).with("National Minimum Wage (Variation of Financial Penalty) Regulations 2014")
      wrapper.expects(:title=).with("Motions to Approve")
      
      @parser.parse
    end
  end
end