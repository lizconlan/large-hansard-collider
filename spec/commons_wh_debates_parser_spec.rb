require './spec/rspec_helper.rb'
require './lib/commons/wh_debates_parser'

describe WHDebatesParser do
  before(:each) do
    Preamble.any_instance.stubs(:save)
    NonContributionPara.any_instance.stubs(:save)
    ContributionPara.any_instance.stubs(:save)
    Timestamp.any_instance.stubs(:save)
    Component.any_instance.stubs(:save)
    DailyPart.any_instance.stubs(:save)
    Debate.any_instance.stubs(:save)
    Question.any_instance.stubs(:save)
    Division.any_instance.stubs(:save)
  end
  
  def stub_part(house, date, part, volume)
    @daily_part = DailyPart.new
    DailyPart.stubs(:find_or_create_by).returns(@daily_part)
    @daily_part.expects(:house=).with(house)
    @daily_part.expects(:date=).with(date)
    if part
      @daily_part.expects(:part=).at_least_once.with(part)
    end
    @daily_part.stubs(:persisted?)
    @daily_part.stubs(:id)
    @daily_part.stubs(:save)
    @daily_part.stubs(:components).returns([])
  end
  
  def stub_page(file)
    html = File.read(file)
    HansardPage.any_instance.stubs(:scrape_metadata)
    HansardPage.any_instance.stubs(:volume).returns("531")
    HansardPage.any_instance.stubs(:part).returns("190")
    HansardPage.any_instance.stubs(:next_url).returns(nil)
    mock_response = mock("response")
    mock_response.expects(:body).at_least_once.returns(html)
    RestClient.expects(:get).at_least_once.returns(mock_response)
    @page = HansardPage.new(@url)
  end
  
  context "in general" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/halltext/110719h0001.htm"
      stub_part("Commons", "2099-01-01", nil, "190")
      
      @parser = WHDebatesParser.new("2099-01-01")
      @parser.expects(:component_prefix).times(2).returns("wh")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should create the Preamble section" do
      stub_page("spec/data/commons/wh_debates.html")
      
      component = Component.new(:ident => "2099-01-01_hansard_c_wh")
      Component.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh").returns(component)
      
      preamble = Preamble.new(:ident => "2099-01-01_hansard_c_wh_000001")
      Preamble.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000001").returns(preamble)
      preamble.expects(:title=).with("Westminster Hall")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000001_p000001").returns(ncpara)
      ncpara.expects(:section=).with(preamble)
      ncpara.expects(:content=).with("Tuesday 19 July 2011")
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:url=).with("#{@url}\#11071984000004")
      ncpara.expects(:column=).with("183WH")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000001_p000002").returns(ncpara)
      ncpara.expects(:section=).with(preamble)
      ncpara.expects(:content=).with("[Jim Dobbin in the Chair]")
      ncpara.expects(:sequence=).with(2)
      ncpara.expects(:url=).with("#{@url}\#11071984000005")
      ncpara.expects(:column=).with("183WH")
      
      #ignore the rest of the file, not relevant
      timestamp = Timestamp.new
      contribution = ContributionPara.new
      debate = Debate.new(:ident => "debate")
      
      Timestamp.expects(:find_or_create_by).at_least_once.returns(timestamp)
      timestamp.expects(:content=).at_least_once
      
      NonContributionPara.expects(:find_or_create_by).with(ident: "debate_p000001").at_least_once.returns(contribution)
      ContributionPara.expects(:find_or_create_by).at_least_once.returns(contribution)
      contribution.expects(:section=).at_least_once
      contribution.expects(:content=).at_least_once
      contribution.expects(:url=).at_least_once
      contribution.expects(:sequence=).at_least_once
      contribution.expects(:column=).at_least_once
      contribution.expects(:member=).at_least_once
      contribution.expects(:speaker_printed_name=).at_least_once
      
      Debate.expects(:find_or_create_by).at_least_once.returns(debate)
      debate.expects(:chair=).with(["Jim Dobbin"])
      debate.expects(:paragraphs).at_least_once.returns([])
      
      @parser.parse
    end
    
    it "should create the Debate section" do
      stub_page("spec/data/commons/wh_debates.html")
      
      component = Component.new(:ident => '2099-01-01_hansard_c_wh')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wh').returns(component)
      
      preamble = Preamble.new(:ident => "preamble")
      Preamble.any_instance.stubs(:paragraphs).returns([])
      Preamble.any_instance.stubs(:title=)
      Preamble.expects(:find_or_create_by).returns(preamble)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: 'preamble_p000001').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by).with(ident: 'preamble_p000002').returns(ncpara)
      ncpara.stubs(:section=)
      ncpara.stubs(:content=)
      ncpara.stubs(:url=)
      ncpara.stubs(:sequence=)
      ncpara.stubs(:column=)
      
      debate = Debate.new(:ident => "2099-01-01_hansard_c_wh_000002")
      Debate.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002").returns(debate)
      debate.expects(:paragraphs).at_least_once.returns([])
      debate.expects(:chair=).with(["Jim Dobbin"])
      debate.expects(:component=).with(component)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wh_000002_p000001').returns(ncpara)
      ncpara.expects(:section=).with(debate)
      ncpara.expects(:content=).with("Motion made, and Question proposed, That the sitting be now adjourned. - (Miss Chloe Smith.)")
      ncpara.expects(:url=).with("#{@url}\#11071984000006")
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:column=).with("183WH")
      
      timestamp = Timestamp.new
      
      Timestamp.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000002").returns(timestamp)
      timestamp.expects(:content=).with("9.30 am")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000003").returns(contribution)
      contribution.expects(:section=).with(debate)
      contribution.expects(:content=).with('Andrew Gwynne (Denton and Reddish) (Lab): Start of speech')
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(3)
      contribution.expects(:column=)
      contribution.expects(:member=).with("Andrew Gwynne")
      contribution.expects(:speaker_printed_name=).with("Andrew Gwynne")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000004").returns(contribution)
      contribution.expects(:section=).with(debate)
      contribution.expects(:content=).with("Continuation of speech")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(4)
      contribution.expects(:member=).with("Andrew Gwynne")
      contribution.expects(:column=).with("184WH")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000005").returns(contribution)
      contribution.expects(:section=).with(debate)
      contribution.expects(:content=).with("Sarah Teather: I shall complete this point first. I have only four minutes left and I have barely answered any of the points raised in the debate.")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(5)
      contribution.expects(:member=).with("Sarah Teather")
      contribution.expects(:speaker_printed_name=).with("Sarah Teather")
      contribution.expects(:column=).with("184WH")
      
      @parser.parse
    end
  end
  
  context "when a new Chair is brought in between debates" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/cm201213/cmhansrd/cm121205/halltext/121205h0001.htm"
      stub_part("Commons", "2099-01-01", nil, "190")
      
      @parser = WHDebatesParser.new("2099-01-01")
      @parser.expects(:component_prefix).times(2).returns("wh")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should correctly record a single Chair for each debate" do
      stub_page("spec/data/commons/wh_debates_mid-session_change.html")
      
      component = Component.new(:ident => '2099-01-01_hansard_c_wh')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wh').returns(component)
      
      preamble = Preamble.new(:ident => "preamble")
      Preamble.any_instance.stubs(:paragraphs).returns([])
      Preamble.any_instance.stubs(:title=)
      Preamble.expects(:find_or_create_by).returns(preamble)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: 'preamble_p000001').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by).with(ident: 'preamble_p000002').returns(ncpara)
      ncpara.stubs(:section=)
      ncpara.stubs(:content=)
      ncpara.stubs(:url=)
      ncpara.stubs(:sequence=)
      ncpara.stubs(:column=)
      
      debate = Debate.new(:ident => "2099-01-01_hansard_c_wh_000002")
      Debate.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002").returns(debate)
      debate.expects(:paragraphs).at_least_once.returns([])
      debate.expects(:title=).with("Unemployment in Scotland")
      debate.expects(:chair=).with(["Ms Nadine Dorries"])
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wh_000002_p000001').returns(ncpara)
      ncpara.expects(:section=).with(debate)
      ncpara.expects(:content=).with("Motion made, and Question proposed, That the sitting be now adjourned. - (Nicky Morgan.)")
      ncpara.expects(:url=)
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:column=)
      
      timestamp = Timestamp.new
      Timestamp.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000002").returns(timestamp)
      timestamp.expects(:content=).with("9.30 am")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000003").returns(contribution)
      contribution.expects(:section=).with(debate)
      contribution.expects(:content=).with('Gemma Doyle (West Dunbartonshire) (Lab/Co-op): It is a pleasure to serve under your chairmanship, Ms Dorries.')
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(3)
      contribution.expects(:column=)
      contribution.expects(:member=).with("Gemma Doyle")
      contribution.expects(:speaker_printed_name=).with("Gemma Doyle")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000004").returns(contribution)
      contribution.expects(:section=).with(debate)
      contribution.expects(:content=).with("However, I first want to look at what the UK Government are - or are not - doing.")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(4)
      contribution.expects(:member=).with("Gemma Doyle")
      contribution.expects(:column=)
      
      
      debate = Debate.new(:ident => "2099-01-01_hansard_c_wh_000003")
      Debate.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000003").returns(debate)
      debate.expects(:paragraphs).at_least_once.returns([])
      debate.expects(:title=).with("Regional Newspapers")
      debate.expects(:chair=).with(["Mr Jim Hood"])
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wh_000003_p000001').returns(ncpara)
      ncpara.expects(:section=).with(debate)
      ncpara.expects(:content=).with("[Mr Jim Hood in the Chair]")
      ncpara.expects(:url=)
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:column=)
      
      timestamp = Timestamp.new
      Timestamp.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000003_p000002").returns(timestamp)
      timestamp.expects(:content=).with("2.30 pm")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000003_p000003").returns(contribution)
      contribution.expects(:section=).with(debate)
      contribution.expects(:content=).with("Mr Jim Hood (in the Chair): Members will have noticed the new clock displays in the Chamber. As before, the top display is the current time and the bottom display, when a speech is not being timed, will show the time it started. If it becomes necessary to introduce a speech limit, the bottom display will change, to show the time remaining to the Member who currently has the Floor. As in the main Chamber, the display can now award an extra minute for the first two interventions in a speech.")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(3)
      contribution.expects(:member=).with("Jim Hood")
      contribution.expects(:speaker_printed_name=).with("Mr Jim Hood")
      contribution.expects(:column=)
      
      @parser.parse
    end
  end
  
  context "when a new Chair is brought in during a debate" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/cm201314/cmhansrd/cm140109/halltext/140109h0001.htm"
      stub_part("Commons", "2099-01-01", nil, "190")
      
      @parser = WHDebatesParser.new("2099-01-01")
      @parser.expects(:component_prefix).times(2).returns("wh")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should correctly record a single Chair for each debate" do
      stub_page("spec/data/commons/wh_debates_mid-debate_change.html")
      
      component = Component.new(:ident => '2099-01-01_hansard_c_wh')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wh').returns(component)
      
      preamble = Preamble.new(:ident => "preamble")
      Preamble.any_instance.stubs(:paragraphs).returns([])
      Preamble.any_instance.stubs(:title=)
      Preamble.expects(:find_or_create_by).returns(preamble)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: 'preamble_p000001').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by).with(ident: 'preamble_p000002').returns(ncpara)
      ncpara.stubs(:section=)
      ncpara.stubs(:content=)
      ncpara.stubs(:url=)
      ncpara.stubs(:sequence=)
      ncpara.stubs(:column=)
      
      debate = Debate.new(:ident => "2099-01-01_hansard_c_wh_000002")
      Debate.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002").returns(debate)
      debate.expects(:paragraphs).at_least_once.returns([])
      debate.expects(:title=).with("Disabled People (Access to Transport)")
      debate.expects(:chair=).with(["Nadine Dorries", "Katy Clark"])
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wh_000002_p000001').returns(ncpara)
      ncpara.expects(:section=).with(debate)
      ncpara.expects(:content=).with("[Relevant documents: Fifth Report of the Transport Committee, Access to Transport for Disabled People, HC 116, and the Government response, HC 870.]")
      ncpara.expects(:url=)
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:column=)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wh_000002_p000002').returns(ncpara)
      ncpara.expects(:section=).with(debate)
      ncpara.expects(:content=).with("Motion made, and Question proposed, That the sitting be now adjourned. - (Karen Bradley.)")
      ncpara.expects(:url=)
      ncpara.expects(:sequence=).with(2)
      ncpara.expects(:column=)
      
      timestamp = Timestamp.new
      Timestamp.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000003").returns(timestamp)
      timestamp.expects(:content=).with("1.30 pm")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000004").returns(contribution)
      contribution.expects(:section=).with(debate)
      contribution.expects(:content=).with('Mrs Louise Ellman (Liverpool, Riverside) (Lab/Co-op): It is a pleasure to serve under your chairmanship, Ms Dorries.')
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(4)
      contribution.expects(:column=)
      contribution.expects(:member=).with("Louise Ellman")
      contribution.expects(:speaker_printed_name=).with("Mrs Louise Ellman")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wh_000002_p000005').returns(ncpara)
      ncpara.expects(:section=).with(debate)
      ncpara.expects(:content=).with("[Katy Clark in the Chair]")
      ncpara.expects(:url=)
      ncpara.expects(:sequence=).with(5)
      ncpara.expects(:column=)
      
      timestamp = Timestamp.new
      Timestamp.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000006").returns(timestamp)
      timestamp.expects(:content=).with("2.58 pm")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000007").returns(contribution)
      contribution.expects(:section=).with(debate)
      contribution.expects(:content=).with("Mrs Ellman: The debate has reinforced the importance of this issue and the importance of the Committee's conducting its report, securing its reply and debating this further with the Minister. I thank all hon. Members who have participated in the debate and contributed to it.")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(7)
      contribution.expects(:column=)
      contribution.expects(:member=).with("Louise Ellman")
      contribution.expects(:speaker_printed_name=).with("Mrs Ellman")
      
      debate = Debate.new(:ident => "2099-01-01_hansard_c_wh_000003")
      Debate.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000003").returns(debate)
      debate.expects(:paragraphs).at_least_once.returns([])
      debate.expects(:title=).with("Global Food Security")
      debate.expects(:chair=).with(["Katy Clark"])
      
      timestamp = Timestamp.new
      Timestamp.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000003_p000001").returns(timestamp)
      timestamp.expects(:content=).with("3.2 pm")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000003_p000002").returns(contribution)
      contribution.expects(:section=).with(debate)
      contribution.expects(:content=).with("Sir Malcolm Bruce (Gordon) (LD): I am glad to have the opportunity to initiate this short debate on the International Development Committee's report on global food security.")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(2)
      contribution.expects(:member=).with("Malcolm Bruce")
      contribution.expects(:speaker_printed_name=).with("Sir Malcolm Bruce")
      contribution.expects(:column=)
      
      @parser.parse
    end
  end
end
