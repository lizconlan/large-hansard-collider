# encoding: UTF-8

require './spec/rspec_helper.rb'
require './lib/commons/petitions_parser'

describe PetitionsParser do
  def stub_saves
    Preamble.any_instance.stubs(:save)
    NonContributionPara.any_instance.stubs(:save)
    ContributionPara.any_instance.stubs(:save)
    ContributionTable.any_instance.stubs(:save)
    Component.any_instance.stubs(:save)
    DailyPart.any_instance.stubs(:save)
    Petition.any_instance.stubs(:save)
    PetitionObservation.any_instance.stubs(:save)
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
  
  context "when given a section containing 2 petitions on a single subject" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/cm201314/cmhansrd/cm140116/petntext/140116p0001.htm"
      stub_saves
      stub_daily_part
      
      @parser = PetitionsParser.new("2099-01-01")
      @parser.stubs(:component_prefix).returns("p")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should create a Preamble, 2 Petitions and a PetitionObservation" do
      stub_page("spec/data/commons/petitions.html")
      HansardPage.expects(:new).returns(@page)
      
      component = Component.new(:ident => '2099-01-01_hansard_c_p')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_p').returns(component)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).at_least_once.returns(ncpara)
      
      preamble = Preamble.new(:ident => "2099-01-01_hansard_c_p_000001")
      Preamble.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_p_000001").returns(preamble)
      preamble.expects(:title=).with("Petitions")
      
      preamble.expects(:paragraphs).at_least_once.returns([ncpara])
      
      petition = Petition.new
      observation = PetitionObservation.new
      
      Petition.expects(:find_or_create_by).times(2).returns(petition)
      PetitionObservation.expects(:find_or_create_by).returns(observation)
      
      @parser.parse
    end
    
    it "should find the petition numbers" do
      stub_page("spec/data/commons/petitions.html")
      HansardPage.expects(:new).returns(@page)
      
      component = Component.new(:ident => '2099-01-01_hansard_c_p')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_p').returns(component)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).at_least_once.returns(ncpara)
      
      preamble = Preamble.new(:ident => "2099-01-01_hansard_c_p_000001")
      Preamble.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_p_000001").returns(preamble)
      
      petition = Petition.new
      observation = PetitionObservation.new
      
      Petition.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_p_000002").returns(petition)
      petition.expects(:number=).with("P001300")
      
      Petition.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_p_000003").returns(petition)
      petition.expects(:number=).with("P001301")
      
      PetitionObservation.expects(:find_or_create_by).returns(observation)
      
      @parser.parse
    end
  end
  
  context "when given a section containing 2 petitions on 2 different subjects" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/cm201314/cmhansrd/cm140212/petntext/140212p0001.htm"
      stub_saves
      stub_daily_part
      
      @parser = PetitionsParser.new("2099-01-01")
      @parser.stubs(:component_prefix).returns("p")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should create a Preamble, 2 Petitions and a PetitionObservation" do
      stub_page("spec/data/commons/petitions.html")
      HansardPage.expects(:new).returns(@page)
      
      component = Component.new(:ident => '2099-01-01_hansard_c_p')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_p').returns(component)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).at_least_once.returns(ncpara)
      
      preamble = Preamble.new(:ident => "2099-01-01_hansard_c_p_000001")
      Preamble.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_p_000001").returns(preamble)
      preamble.expects(:title=).with("Petitions")
      
      preamble.expects(:paragraphs).at_least_once.returns([ncpara])
      
      petition = Petition.new
      observation = PetitionObservation.new
      
      Petition.expects(:find_or_create_by).times(2).returns(petition)
      PetitionObservation.expects(:find_or_create_by).returns(observation)
      
      @parser.parse
    end
    
    it "should find the petition titles, departments and numbers" do
      stub_page("spec/data/commons/petitions_2.html")
      HansardPage.expects(:new).returns(@page)
      
      component = Component.new(:ident => '2099-01-01_hansard_c_p')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_p').returns(component)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).at_least_once.returns(ncpara)
      
      preamble = Preamble.new(:ident => "2099-01-01_hansard_c_p_000001")
      Preamble.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_p_000001").returns(preamble)
      
      petition = Petition.new
      observation = PetitionObservation.new
      
      Petition.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_p_000002").returns(petition)
      petition.expects(:number=).with("P001304")
      petition.expects(:department=).with("Communities and Local Government")
      petition.expects(:title=).with("Proposed Bund Construction on Oregon Close, Kingswinford, Dudley")
      
      Petition.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_p_000004").returns(petition)
      petition.expects(:number=).with("P001306")
      petition.expects(:department=).with("Culture, Media and Sport")
      petition.expects(:title=).with("Ennerdale Swimming Pool (Kingston upon Hull)")
      
      PetitionObservation.expects(:find_or_create_by).times(2).returns(observation)
      
      @parser.parse
    end
  end
end
