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
    @page = mock("HansardPage")
    HansardPage.stubs(:new).returns(@page)
    @page.expects(:next_url).returns(nil)
    @page.expects(:doc).returns(Nokogiri::HTML(html))
    @page.expects(:url).at_least_once.returns(@url)
    @page.stubs(:volume).returns("531")
    @page.stubs(:part).returns("190")
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
      ncpara.expects(:fragment=).with(preamble)
      ncpara.expects(:content=).with("Tuesday 19 July 2011")
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:url=).with("#{@url}\#11071984000004")
      ncpara.expects(:column=).with("183WH")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000001_p000002").returns(ncpara)
      ncpara.expects(:fragment=).with(preamble)
      ncpara.expects(:content=).with("[Jim Dobbin in the Chair]")
      ncpara.expects(:sequence=).with(2)
      ncpara.expects(:url=).with("#{@url}\#11071984000005")
      ncpara.expects(:column=).with("183WH")
      
      preamble.expects(:paragraphs).at_least_once.returns([ncpara])
      
      #ignore the rest of the file, not relevant
      timestamp = Timestamp.new
      contribution = ContributionPara.new
      debate = Debate.new(:ident => "debate")
      
      Timestamp.expects(:find_or_create_by).at_least_once.returns(timestamp)
      timestamp.expects(:content=).at_least_once
      
      NonContributionPara.expects(:find_or_create_by).with(ident: "debate_p000001").at_least_once.returns(contribution)
      ContributionPara.expects(:find_or_create_by).at_least_once.returns(contribution)
      contribution.expects(:fragment=).at_least_once
      contribution.expects(:content=).at_least_once
      contribution.expects(:url=).at_least_once
      contribution.expects(:sequence=).at_least_once
      contribution.expects(:column=).at_least_once
      contribution.expects(:member=).at_least_once
      contribution.expects(:speaker_printed_name=).at_least_once
      
      Debate.expects(:find_or_create_by).at_least_once.returns(debate)
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
      ncpara.stubs(:fragment=)
      ncpara.stubs(:content=)
      ncpara.stubs(:url=)
      ncpara.stubs(:sequence=)
      ncpara.stubs(:column=)
      
      debate = Debate.new(:ident => "2099-01-01_hansard_c_wh_000002")
      Debate.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002").returns(debate)
      debate.expects(:paragraphs).at_least_once.returns([])

      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wh_000002_p000001').returns(ncpara)
      ncpara.expects(:fragment=).with(debate)
      ncpara.expects(:content=).with("Motion made, and Question proposed, That the sitting be now adjourned. - (Miss Chloe Smith.)")
      ncpara.expects(:url=).with("#{@url}\#11071984000006")
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:column=).with("183WH")
      
      timestamp = Timestamp.new
      
      Timestamp.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000002").returns(timestamp)
      timestamp.expects(:content=).with("9.30 am")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000003").returns(contribution)
      contribution.expects(:fragment=).with(debate)
      contribution.expects(:content=).with('Andrew Gwynne (Denton and Reddish) (Lab): Start of speech')
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(3)
      contribution.expects(:column=)
      contribution.expects(:member=).with("Andrew Gwynne")
      contribution.expects(:speaker_printed_name=).with("Andrew Gwynne")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000004").returns(contribution)
      contribution.expects(:fragment=).with(debate)
      contribution.expects(:content=).with("Continuation of speech")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(4)
      contribution.expects(:member=).with("Andrew Gwynne")
      contribution.expects(:column=).with("184WH")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wh_000002_p000005").returns(contribution)
      contribution.expects(:fragment=).with(debate)
      contribution.expects(:content=).with("Sarah Teather: I shall complete this point first. I have only four minutes left and I have barely answered any of the points raised in the debate.")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(5)
      contribution.expects(:member=).with("Sarah Teather")
      contribution.expects(:speaker_printed_name=).with("Sarah Teather")
      contribution.expects(:column=).with("184WH")
      
      @parser.parse
    end
  end
end
