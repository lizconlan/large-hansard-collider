#encoding: utf-8

require './spec/rspec_helper.rb'
require './lib/lords/debates_parser'

describe LordsDebatesParser do
  before(:each) do
    Intro.any_instance.stubs(:save)
    NonContributionPara.any_instance.stubs(:save)
    ContributionPara.any_instance.stubs(:save)
    Timestamp.any_instance.stubs(:save)
    Component.any_instance.stubs(:save)
    DailyPart.any_instance.stubs(:save)
    Debate.any_instance.stubs(:save)
    Question.any_instance.stubs(:save)
    Division.any_instance.stubs(:save)
    MemberIntroduction.any_instance.stubs(:save)
    LordsDebatesParser.any_instance.stubs(:house=)
  end
  
  def stub_page(file)
    html = File.read(file)
    @page = mock("HansardPage")
    HansardPage.stubs(:new).returns(@page)
    @page.expects(:next_url).returns(nil)
    @page.expects(:doc).at_least_once.returns(Nokogiri::HTML(html))
    @page.expects(:url).at_least_once.returns(@url)
    @page.stubs(:volume).returns("723")
    @page.stubs(:part).returns("94")
  end
  
  def stub_part(house, date, part, volume)
    @daily_part = DailyPart.new
    DailyPart.stubs(:find_or_create_by_id).returns(@daily_part)
    @daily_part.expects(:house=).at_least_once.with(house)
    @daily_part.expects(:date=).at_least_once.with(date)
    if part
      @daily_part.expects(:part=).at_least_once.with(part)
    end
    @daily_part.stubs(:persisted?)
    @daily_part.stubs(:id)
    @daily_part.expects(:volume=).at_least_once.with(volume)
    @daily_part.stubs(:save)
    @daily_part.stubs(:components).returns([])
  end
  
  # context "in general" do
  #   before(:each) do
  #     @url = "http://www.publications.parliament.uk/pa/ld201011/ldhansrd/text/110117-0001.htm"
  #     stub_part("Lords", "2099-01-01", "94", "723")
  #     
  #     @component = Component.new
  #     @component.stubs(:fragments).returns([])
  #     Component.stubs(:find_or_create_by_id).returns(@component)
  #     
  #     @parser = LordsDebatesParser.new("2099-01-01")
  #   end
  # end
  
  
  context "when handling Member Introductions within Debates" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/ld201011/ldhansrd/text/110111-0001.htm"
      stub_part("Lords", "2099-01-01", "94", "723")
      
      @component = Component.new
      @component.stubs(:fragments).returns([])
      @component.stubs(:find_or_create_by_id).returns(@component)
      @component.stubs(:id).returns("2099-01-01_hansard_l_d")
      
      @parser = LordsDebatesParser.new("2099-01-01")
      @parser.stubs(:link_to_first_page).returns(@url)
    end
    
    it "should correctly recognise the Member Introductions" do
      stub_page("spec/data/lords/debates/introductions.html")
      
      Component.expects(:find_or_create_by_id).returns(@component)
      
      intro = Intro.new(:id => "2099-01-01_hansard_l_d_000001")
      Intro.expects(:find_or_create_by_id).with("2099-01-01_hansard_l_d_000001").returns(intro)
      intro.expects(:title=).with('House of Lords')
      intro.expects(:component=).with(@component)
      intro.expects(:url=).with("#{@url}\#11011158000521")
      intro.expects(:sequence=).with(1)
      intro.expects(:columns=).with(["1285"])
      
      ncpara1 = NonContributionPara.new(:id => "2099-01-01_hansard_l_d_000001_p000001")
      NonContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_l_d_000001_p000001").returns(ncpara1)
      ncpara1.expects(:text=).with("Tuesday, 11 January 2011.")
      ncpara1.expects(:column=).with("1285")
      ncpara1.expects(:column).at_least_once.returns("1285")
      ncpara1.expects(:fragment=).with(intro)
      
      ncpara2 = NonContributionPara.new(:id => "2099-01-01_hansard_l_d_000001_p000002")
      NonContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_l_d_000001_p000002").returns(ncpara2)
      ncpara2.expects(:text=).with("Prayers-read by the Lord Bishop of Gloucester.")
      ncpara2.expects(:fragment=).with(intro)
      ncpara2.expects(:column=).with("1285")
      intro.expects(:paragraphs).at_least_once.returns([ncpara1, ncpara2])
      
      member_intro = MemberIntroduction.new(:id => "2099-01-01_hansard_l_d_000002")
      MemberIntroduction.expects(:find_or_create_by_id).with("2099-01-01_hansard_l_d_000002").returns(member_intro)
      member_intro.expects(:title=).with("Introduction: Lord True")
      member_intro.expects(:members=).with(["Lord True"])
      
      timestamp = Timestamp.new(:id => "2099-01-01_hansard_l_d_000002_p000001")
      Timestamp.expects(:find_or_create_by_id).with("2099-01-01_hansard_l_d_000002_p000001").returns(timestamp)
      timestamp.expects(:text=).with("2.22 pm")
      timestamp.expects(:column=).at_least_once.with("1285")
      timestamp.expects(:fragment=).with(member_intro)
      
      ncpara = NonContributionPara.new(:id => '2099-01-01_hansard_l_d_000002_p000002')
 NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_l_d_000002_p000002').returns(ncpara)
      ncpara.expects(:text=).with("Nicholas Edward True, Esquire, CBE, having been created Baron True, of East Sheen in the County of Surrey, was introduced and took the oath, supported by Lord Strathclyde and Lord Howard of Rising, and signed an undertaking to abide by the Code of Conduct.")
      ncpara.expects(:fragment=).with(member_intro)
      member_intro.expects(:paragraphs).at_least_once.returns([ncpara])
      
      member_intro = MemberIntroduction.new(:id => "2099-01-01_hansard_l_d_000003")
      MemberIntroduction.expects(:find_or_create_by_id).with("2099-01-01_hansard_l_d_000003").returns(member_intro)
      member_intro.expects(:title=).with("Introduction: Baroness Jolly")
      member_intro.expects(:members=).with(["Baroness Jolly"])
      
      timestamp = Timestamp.new(:id => "2099-01-01_hansard_l_d_000003_p000001")
      Timestamp.expects(:find_or_create_by_id).with("2099-01-01_hansard_l_d_000003_p000001").returns(timestamp)
      timestamp.expects(:text=).with("2.27 pm")
      timestamp.expects(:fragment=).with(member_intro)
      
      ncpara = NonContributionPara.new(:id => "2099-01-01_hansard_l_d_000003_p000002")
      NonContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_l_d_000003_p000002").returns(ncpara)
      ncpara.expects(:fragment=).with(member_intro)
      ncpara.expects(:text=).with("Judith Anne Jolly, having been created Baroness Jolly, of Congdon's Shop in the County of Cornwall, was introduced and took the oath, supported by Lord Tyler and Lord Teverson, and signed an undertaking to abide by the Code of Conduct.")
      member_intro.expects(:paragraphs).at_least_once.returns([ncpara])
      
      @parser.parse_pages
    end
    
    # it "should handle the Intro properly and create Debate elements for each debate" do
    #   stub_page("spec/data/lords/debate_excerpt_jan_2011.html")
    #   
    #   ncpara = NonContributionPara.new
    #   NonContributionPara.expects(:find_or_create_by_id).returns(ncpara)
    #   NonContributionPara.any_instance.stubs(:fragment=)
    #   NonContributionPara.any_instance.stubs(:text=)
    #   NonContributionPara.any_instance.stubs(:sequence=)
    #   NonContributionPara.any_instance.stubs(:url=)
    #   NonContributionPara.any_instance.stubs(:column=)
    #   
    #   @component.stubs(:id).returns("2099-01-01_hansard_c_d")
    #   
    #   intro = Intro.new
    #   Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001').returns(intro)
    #   intro.expects(:title=).with('Backbench Business')
    #   intro.expects(:component=).with(@component)
    #   intro.expects(:url=)
    #   intro.expects(:sequence=).with(1)
    #   intro.stubs(:columns=)
    #   intro.expects(:paragraphs).at_least_once.returns([])
    #   intro.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000001')
    #   
    #   ncpara.expects(:text=).with("[30th Allotted Day]")
    #   
    #   debate = Debate.new
    #   Debate.any_instance.stubs(:paragraphs).returns([])
    #   Debate.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002').returns(debate)
    #   debate.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000002')
    #   debate.expects(:title=).with("Summer Adjournment")
    #   
    #   timestamp = Timestamp.new
    #   Timestamp.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000002_p000001").returns(timestamp)
    #   timestamp.expects(:text=).with("2.44 pm")
    #   timestamp.expects(:column=).with("831")
    #   
    #   contribution = ContributionPara.new
    #   ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000002_p000002").returns(contribution)
    #   contribution.expects(:text=).with("Natascha Engel (North East Derbyshire) (Lab):I beg to move,")
    #   contribution.expects(:column=).with("831")
    #   contribution.expects(:member=).with("Natascha Engel")
    #   contribution.expects(:speaker_printed_name=).with("Natascha Engel")
    #   
    #   ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000002_p000003").returns(contribution)
    #   contribution.expects(:text=).with("That this House has considered matters to be raised before the forthcoming adjournment.")
    #   contribution.expects(:column=).with("831")
    #   contribution.expects(:member=).with("Natascha Engel")
    #   
    #   ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000002_p000004").returns(contribution)
    #   contribution.expects(:text=).with("Thank you for calling me, Mr Deputy Speaker; I thought that this moment would never arrive. A total of 66 Members want to participate in the debate, including our newest Member - my hon. Friend the Member for Inverclyde (Mr McKenzie) - who is hoping to make his maiden speech. [Hon. Members: \"Hear, hear.\"] It is unfortunate therefore that two Government statements, important though they both were, have taken almost two hours out of Back Benchers' time. To set an example of brevity and to prepare us for all the constituency carnivals and fairs at which we will be spending most of our time during the recess, I hereby declare the debate open.")
    #   contribution.expects(:column=).with("831")
    #   contribution.expects(:member=).with("Natascha Engel")
    #   
    #   ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000002_p000005").returns(contribution)
    #   contribution.expects(:text=).with("Mr Deputy Speaker (Mr Lindsay Hoyle): We are now coming to a maiden speech, and I remind hon. Members not to intervene on it.")
    #   contribution.expects(:column=).with("831")
    #   contribution.expects(:member=).with("Lindsay Hoyle")
    #   contribution.expects(:speaker_printed_name=).with("Mr Deputy Speaker (Mr Lindsay Hoyle)")
    #   
    #   debate = Debate.new
    #   Debate.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000003').returns(debate)
    #   debate.expects(:title=).with('Business, innovation and skills')
    #   debate.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000003')
    #   
    #   Timestamp.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000003_p000001').returns(timestamp)
    #   timestamp.expects(:text=).with("2.45 pm")
    #   timestamp.expects(:column=).with("832")
    #   
    #   ContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000003_p000002').returns(contribution)
    #   contribution.expects(:text=).with('Mr Iain McKenzie (Inverclyde) (Lab): Thank you, Mr Deputy Speaker, for calling me in this debate to make my maiden speech. I regard it as both a privilege and an honour to represent the constituency of Inverclyde. My constituency has been served extremely well by many accomplished individuals; however, I am only the second Member for Inverclyde to have been born in Inverclyde. The first was, of course, David Cairns.')
    #   contribution.expects(:member=).with("Iain McKenzie")
    #   contribution.expects(:speaker_printed_name=).with("Mr Iain McKenzie")
    #   contribution.expects(:column=).with("832")
    #   
    #   ContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000003_p000003').returns(contribution)
    #   contribution.expects(:text=).with('My two immediate predecessors in my seat, which has often had its boundaries changed, were Dr Norman Godman and the late David Cairns. Dr Godman served in the House for 18 years, and his hard work and enduring commitment to the peace process in Northern Ireland earned him a great deal of respect and admiration. David Cairns was an excellent MP for Inverclyde; his parliamentary career was cut all too short by his sudden death, and I am well aware of the great respect that all parties had for David, as did the people of Inverclyde, as reflected in the large majority he held in the 2010 general election. If I can serve my constituents half as well as David, I shall be doing well indeed.')
    #   contribution.expects(:column=).with("832")
    #   contribution.expects(:member=).with("Iain McKenzie")
    #   
    #   @parser.parse_pages
    # end
  end
  
  # context "when handling the Oral Answers component" do
  #   before(:each) do
  #     @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
  #     stub_part("Commons", "2099-01-01", nil, "531")
  #     
  #     @parser = CommonsDebatesParser.new("2099-01-01")
  #     @parser.expects(:component_prefix).returns("d")
  #     @parser.expects(:link_to_first_page).returns(@url)
  #   end
  #   
  #   it "should find and deal with the main heading and both intros" do
  #     stub_page("spec/data/commons/debates_and_oral_answers_header.html")
  #     HansardPage.expects(:new).returns(@page)
  #     
  #     component = Component.new
  #     Component.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(component)
  #     component.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d')
  #     
  #     intro = Intro.new
  #     Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001').returns(intro)
  #     intro.expects(:title=).with('House of Commons')
  #     intro.expects(:component=).with(component)
  #     intro.expects(:url=).with("#{@url}\#11071988000007")
  #     intro.expects(:sequence=).with(1)
  #     intro.stubs(:columns=)
  #     intro.expects(:paragraphs).at_least_once.returns([])
  #     intro.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000001')
  #     
  #     ncpara = NonContributionPara.new
  #     NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001_p000001').returns(ncpara)
  #     ncpara.expects(:text=).with("Tuesday 19 July 2011")
  #     
  #     ncpara = NonContributionPara.new
  #     NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001_p000002').returns(ncpara)
  #     ncpara.expects(:text=).with("The House met at half-past Eleven o'clock")
  #     
  #     ncpara = NonContributionPara.new
  #     NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001_p000003').returns(ncpara)
  #     ncpara.expects(:text=).with("Prayers")
  #     
  #     ncpara = NonContributionPara.new
  #     NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001_p000004').returns(ncpara)
  #     ncpara.expects(:text=).with("[Mr Speaker in the Chair]")
  #     
  #     intro = Intro.new
  #     Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002').returns(intro)
  #     intro.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000002')
  #     intro.expects(:title=).with("Oral Answers to Questions")
  #     intro.stubs(:paragraphs).returns([])
  #           
  #     @parser.parse_pages
  #   end
  #   
  #   it "should create a Question for each question found" do
  #     stub_page("spec/data/commons/debates_and_oral_answers.html")
  #     
  #     component = Component.new
  #     Component.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(component)
  #     Component.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d')
  #     
  #     intro = Intro.new
  #     Intro.any_instance.stubs(:paragraphs).returns([])
  #     intro.stubs(:text=)
  #     intro.stubs(:id).returns("intro")
  #     Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001').returns(intro)
  #     Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002').returns(intro)
  #     
  #     ncpara = NonContributionPara.new
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000001').returns(ncpara)
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000002').returns(ncpara)
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000003').returns(ncpara)
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000004').returns(ncpara)
  #     
  #     question = Question.new
  #     Question.any_instance.stubs(:paragraphs).returns([])
  #     Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003").returns(question)
  #     question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000003")
  #     question.expects(:department=).with("Foreign and Commonwealth Office")
  #     question.expects(:title=).with("Syria")
  #     question.expects(:number=).with("66855")
  #     question.expects(:url=).with("#{@url}\#11071988000022")
  #     
  #     ncpara = NonContributionPara.new
  #     NonContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000001").returns(ncpara)
  #     ncpara.expects(:text=).with("The Secretary of State was asked - ")
  #     ncpara.expects(:fragment=).with(question)
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000002").returns(contribution)
  #     contribution.expects(:text=).with("1. Mr David Hanson (Delyn) (Lab): When he next expects to discuss the situation in Syria with his US counterpart. [66855]")
  #     contribution.expects(:member=).with("David Hanson")
  #     contribution.expects(:speaker_printed_name=).with("Mr David Hanson")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000003").returns(contribution)
  #     contribution.expects(:text=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague): I am in regular contact with Secretary Clinton and I last discussed Syria with her on Friday.")
  #     contribution.expects(:member=).with("William Hague")
  #     contribution.expects(:speaker_printed_name=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague)")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000004").returns(contribution)
  #     contribution.expects(:text=).with("Mr Hanson: I thank the Foreign Secretary for that answer. Given the recent violence, including the reported shooting of unarmed protesters, does he agree with Secretary of State Clinton that the Syrian Government have lost legitimacy? Given the level of violence, particularly the attacks on the US embassy and the French embassy, what steps is he taking to ensure the security of British citizens who work for the United Kingdom and are operating in Syria now?")
  #     contribution.expects(:member=).with("David Hanson")
  #     contribution.expects(:speaker_printed_name=).with("Mr Hanson")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000005").returns(contribution)
  #     contribution.expects(:text=).with("Mr Hague: The right hon. Gentleman raises some important issues in relation to recent events in Syria. We absolutely deplore the continuing violence against protesters. Reports overnight from the city of Homs suggest that between 10 and 14 people were killed, including a 12-year-old child. We have condemned the attacks on the American and French embassies and we called in the Syrian ambassador last Wednesday to deliver our protests and to demand that Syria observes the requirements of the Vienna convention. The US and British Governments are united in saying that President Assad is losing legitimacy and should reform or step aside, and that continues to be our message.")
  #     contribution.expects(:member=).with("William Hague")
  #     contribution.expects(:speaker_printed_name=).with("Mr Hague")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000006").returns(contribution)
  #     contribution.expects(:text=).with("Mr Philip Hollobone (Kettering) (Con): Iran has been involved in training Syrian troops and providing materi\303\251l assistance, including crowd-dispersal equipment. What assessment has the Foreign Secretary made of the dark hand of Iran in fomenting trouble in the middle east and in supporting illegitimate regimes?")
  #     contribution.expects(:member=).with("Philip Hollobone")
  #     contribution.expects(:speaker_printed_name=).with("Mr Philip Hollobone")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000007").returns(contribution)
  #     contribution.expects(:text=).with("Mr Hague: Iran has certainly been involved in the way that my hon. Friend describes, and I set out a few weeks ago that I believed it to be involved in that way. It shows the extraordinary hypocrisy of the Iranian leadership")
  #     contribution.expects(:member=).with("William Hague")
  #     contribution.expects(:speaker_printed_name=).with("Mr Hague")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000008").returns(contribution)
  #     contribution.expects(:text=).with("on this that it has been prepared to encourage protests in Egypt, Tunisia and other countries while it has brutally repressed protest in its own country and is prepared to connive in doing so in Syria.")
  #     contribution.expects(:member=).with("William Hague")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000009").returns(contribution)
  #     contribution.expects(:text=).with("Stephen Twigg (Liverpool, West Derby) (Lab/Co-op): Does the Foreign Secretary agree that the world has been far too slow in its response to the appalling abuses of human rights in Syria? Surely, after the events of the weekend and the past few days in particular, there is now an urgent need for a clear and strong United Nations Security Council resolution.")
  #     contribution.expects(:member=).with("Stephen Twigg")
  #     contribution.expects(:speaker_printed_name=).with("Stephen Twigg")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000010").returns(contribution)
  #     contribution.expects(:text=).with("Mr Hague: I think the world has been not so much slow as not sufficiently united on this. It has not been possible for the Arab League to arrive at a clear, strong position, which makes the situation entirely different to that in Libya, where the Arab League called on the international community to assist and intervene. There has not been the necessary unity at the United Nations Security Council and at times Russia has threatened to veto any resolution. Our resolution, which was put forward with our EU partners, remains very much on the table and certainly has the support of nine countries. We would like the support of more than nine countries to be able to put it to a vote in the Security Council, but it is very much on the table and we reserve the right at any time to press it to a vote in the United Nations. The hon. Gentleman is quite right to say that recent events add further to the case for doing so.")
  #     contribution.expects(:member=).with("William Hague")
  #     contribution.expects(:speaker_printed_name=).with("Mr Hague")
  #     
  #     question = Question.new
  #     Question.any_instance.stubs(:paragraphs).returns([])
  #     Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004").returns(question)
  #     question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000004")
  #     question.expects(:department=).with("Foreign and Commonwealth Office")
  #     question.expects(:title=).with("Nuclear Non-proliferation and Disarmament")
  #     question.expects(:number=).with("66858")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004_p000001").returns(contribution)
  #     contribution.expects(:text=).with("3. Paul Flynn (Newport West) (Lab): What recent progress his Department has made on nuclear non-proliferation and disarmament. [66858]")
  #     contribution.expects(:member=).with("Paul Flynn")
  #     contribution.expects(:speaker_printed_name=).with("Paul Flynn")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004_p000002").returns(contribution)
  #     contribution.expects(:text=).with("The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt): We continue to work across all three pillars of the non-proliferation treaty to build on the success of last year's review conference in New York. I am particularly proud of the work we have done towards ensuring the first conference of nuclear weapon states, which was held recently in Paris - the P5 conference - in which further progress was made, particularly towards disarmament.")
  #     contribution.expects(:member=).with("Alistair Burt")
  #     contribution.expects(:speaker_printed_name=).with("The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt)")
  #     
  #     @parser.parse_pages
  #   end
  #   
  #   it "should deal with the Topical Questions component" do
  #     stub_page("spec/data/commons/topical_questions.html")
  #     
  #     component = Component.new
  #     Component.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(component)
  #     component.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d')
  #     
  #     intro = Intro.new
  #     Intro.any_instance.stubs(:paragraphs).returns([])
  #     intro.stubs(:text=)
  #     intro.stubs(:id).returns("intro")
  #     Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001').returns(intro)
  #     Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002').returns(intro)
  #     
  #     ncpara = NonContributionPara.new
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000001').returns(ncpara)
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000002').returns(ncpara)
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000003').returns(ncpara)
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000004').returns(ncpara)
  #     
  #     question = Question.new
  #     Question.any_instance.stubs(:paragraphs).returns([])
  #     Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003").returns(question)
  #     question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000003")
  #     question.expects(:department=).with("Foreign and Commonwealth Office")
  #     question.expects(:title=).with("Nuclear Non-proliferation and Disarmament")
  #     question.expects(:number=).with("66858")
  #     
  #     ncpara = NonContributionPara.new
  #     NonContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000001").returns(ncpara)
  #     ncpara.expects(:text=).with("The Secretary of State was asked - ")
  #     ncpara.expects(:fragment=).with(question)
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000002").returns(contribution)
  #     contribution.expects(:text=).with("3. Paul Flynn (Newport West) (Lab): What recent progress his Department has made on nuclear non-proliferation and disarmament. [66858]")
  #     contribution.expects(:member=).with("Paul Flynn")
  #     contribution.expects(:speaker_printed_name=).with("Paul Flynn")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000003").returns(contribution)
  #     contribution.expects(:text=).with("The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt): We continue to work across all three pillars of the non-proliferation treaty to build on the success of last year's review conference in New York. I am particularly proud of the work we have done towards ensuring the first conference of nuclear weapon states, which was held recently in Paris - the P5 conference - in which further progress was made, particularly towards disarmament.")
  #     contribution.expects(:member=).with("Alistair Burt")
  #     contribution.expects(:speaker_printed_name=).with("The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt)")
  #     
  #     question = Question.new
  #     Question.any_instance.stubs(:paragraphs).returns([])
  #     Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004").returns(question)
  #     question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000004")
  #     question.expects(:department=).with("Foreign and Commonwealth Office")
  #     question.expects(:title=).with("Topical Questions - T1")
  #     question.expects(:number=).with("66880")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004_p000001").returns(contribution)
  #     contribution.expects(:text=).with("T1. [66880] Harriett Baldwin (West Worcestershire) (Con): If he will make a statement on his departmental responsibilities.")
  #     contribution.expects(:member=).with("Harriett Baldwin")
  #     contribution.expects(:speaker_printed_name=).with("Harriett Baldwin")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004_p000002").returns(contribution)
  #     contribution.expects(:text=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague): Statement goes here")
  #     contribution.expects(:member=).with("William Hague")
  #     contribution.expects(:speaker_printed_name=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague)")
  #     
  #     question = Question.new
  #     Question.any_instance.stubs(:paragraphs).returns([])
  #     Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000005").returns(question)
  #     question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000005")
  #     question.expects(:department=).with("Foreign and Commonwealth Office")
  #     question.expects(:title=).with("Topical Questions - T2")
  #     question.expects(:number=).with("66881")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000005_p000001").returns(contribution)
  #     contribution.expects(:text=).with("T2. [66881] Stephen Mosley (City of Chester) (Con): One of the remaining issues in South Sudan is that of Abyei. Will my right hon. Friend give us an update on what action is being taken to ensure that the promised referendum in Abyei goes ahead successfully?")
  #     contribution.expects(:member=).with("Stephen Mosley")
  #     contribution.expects(:speaker_printed_name=).with("Stephen Mosley")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000005_p000002").returns(contribution)
  #     contribution.expects(:text=).with("Mr Hague: The urgent thing has been to bring peace and order to Abyei, and that is something that I have discussed with those in the north and south in Sudan, as well as with the Ethiopian Prime Minister and Foreign Minister on my visit to Ethiopia 10 days or so ago. Up to 4,200 Ethiopian troops will go to Abyei, and we have been active in quickly passing the necessary United Nations authority for them to do so. That is designed to pave the way for political progress in Abyei, but the most urgent thing has been to get that Ethiopian force there and to prevent continuing violence.")
  #     contribution.expects(:member=).with("William Hague")
  #     contribution.expects(:speaker_printed_name=).with("Mr Hague")
  #     
  #     @parser.parse_pages
  #   end
  #   
  #   it "should not treat the first Debate as another Question" do
  #     stub_page("spec/data/commons/topical_questions_end.html")
  #     
  #     component = Component.new
  #     Component.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(component)
  #     component.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d')
  #     
  #     intro = Intro.new
  #     Intro.any_instance.stubs(:paragraphs).returns([])
  #     intro.stubs(:text=)
  #     intro.stubs(:id).returns("intro")
  #     Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001').returns(intro)
  #     Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002').returns(intro)
  #     
  #     ncpara = NonContributionPara.new
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000001').returns(ncpara)
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000002').returns(ncpara)
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000003').returns(ncpara)
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000004').returns(ncpara)
  #     
  #     question = Question.new
  #     Question.any_instance.stubs(:paragraphs).returns([])
  #     Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003").returns(question)
  #     question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000003")
  #     question.expects(:department=).with("Foreign and Commonwealth Office")
  #     question.expects(:title=).with("Topical Questions - T1")
  #     question.expects(:number=).with("66880")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000001").returns(contribution)
  #     contribution.expects(:text=).with("T1. [66880] Harriett Baldwin (West Worcestershire) (Con): If he will make a statement on his departmental responsibilities.")
  #     contribution.expects(:member=).with("Harriett Baldwin")
  #     contribution.expects(:speaker_printed_name=).with("Harriett Baldwin")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000002").returns(contribution)
  #     contribution.expects(:text=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague): Statement goes here")
  #     contribution.expects(:member=).with("William Hague")
  #     contribution.expects(:speaker_printed_name=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague)")
  #     
  #     debate = Debate.new
  #     Debate.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004").returns(debate)
  #     debate.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000004")
  #     debate.stubs(:paragraphs).returns([])
  #     
  #     timestamp = Timestamp.new
  #     Timestamp.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004_p000001").returns(timestamp)
  #     timestamp.expects(:text=).with("12.34 pm")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004_p000002").returns(contribution)
  #     contribution.expects(:text=)
  #     contribution.expects(:member=).with("Hilary Benn")
  #     contribution.expects(:speaker_printed_name=).with("Hilary Benn")
  #     
  #     @parser.parse_pages
  #   end
  # end
  # 
  # context "when handling a Debate containing a Division" do
  #   before(:each) do
  #     @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
  #     stub_part("Commons", "2099-01-01", nil, "531")
  #     
  #     @parser = CommonsDebatesParser.new("2099-01-01")
  #     @parser.expects(:component_prefix).returns("d")
  #     @parser.expects(:link_to_first_page).returns(@url)
  #   end
  #   
  #   it "should not handle store the Division with Ayes and Noes" do
  #     stub_page("spec/data/commons/debate_with_division.html")
  #     
  #     component = Component.new
  #     Component.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(component)
  #     component.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d')
  #     
  #     intro = Intro.new
  #     Intro.any_instance.stubs(:paragraphs).returns([])
  #     intro.stubs(:text=)
  #     intro.stubs(:id).returns("intro")
  #     Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001').returns(intro)
  #     
  #     ncpara = NonContributionPara.new
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000001').returns(ncpara)
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000002').returns(ncpara)
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000003').returns(ncpara)
  #     NonContributionPara.expects(:find_or_create_by_id).with('intro_p000004').returns(ncpara)
  #     
  #     debate = Debate.new
  #     Debate.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000002").returns(debate)
  #     debate.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000002")
  #     debate.stubs(:paragraphs).returns([])
  #     debate.expects(:title=).with("Public Bodies Bill [Lords]")
  #     debate.expects(:url=).with("#{@url}\#11071272000001")
  #     
  #     ncpara = NonContributionPara.new
  #     NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002_p000001').returns(ncpara)
  #     ncpara.expects(:text=).with("[Relevant documents: The Fifth Report from the Public Administration Select Committee, Smaller Government: Shrinking the Quango State, HC 537, and the Government response, Cm 8044 .]")
  #     
  #     NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002_p000002').returns(ncpara)
  #     ncpara.expects(:text=).with("Second Reading")
  #     
  #     contribution = ContributionPara.new
  #     ContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002_p000003').returns(contribution)
  #     contribution.expects(:text=).with("Mr Hurd: In summary, the reforms we have proposed and that have been debated again today will produce a leaner and more effective system of public bodies centred on the principle of ministerial accountability. We have listened intently to the comments and concerns expressed during the debate and recognise that there are areas where the Government can helpfully produce further clarity and assurance, and the Deputy Leader of the House and I look forward to continuing to engage with hon. Members in Committee and elsewhere.")
  #     
  #     ContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002_p000004').returns(contribution)
  #     contribution.expects(:text=).with("However, I reiterate my hope that the House can come together in support of the belief that ministerial accountability for public functions and the use of public money should be at the heart of how we conduct ourselves. The Government believe that the proposals embodied in the Bill and in our plans for a regular comprehensive review of all public bodies will set a new standard for the management and review of public bodies, and on that basis I commend the Bill to the House.")
  #     
  #     NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002_p000005').returns(ncpara)
  #     ncpara.expects(:text=).with("Question put, That the amendment be made.")
  #     
  #     division = Division.new
  #     Division.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002_p000006').returns(division)
  #     division.expects(:number=).with('321')
  #     division.expects(:timestamp=).with("9.59 pm")
  #     division.expects(:tellers_ayes=).with('Lilian Greenwood and Gregg McClymont')
  #     division.expects(:tellers_noes=).with('James Duddridge and Norman Lamb')
  #     division.expects(:ayes=).with(['Abbott, Ms Diane', 'Abrahams, Debbie', 'Ainsworth, rh Mr Bob', 'Morris, Grahame M. (Easington)'])
  #     division.expects(:noes=).with(['Adams, Nigel', 'Afriyie, Adam', 'Aldous, Peter', 'Alexander, rh Danny', 'Davies, David T. C. (Monmouth)'])
  #     division.expects(:text=).with('division')
  #     division.expects(:text=).with("The House divided: Ayes 231, Noes 307. \n 9.59 pm - Division No. 321 \n Ayes: Abbott, Ms Diane; Abrahams, Debbie; Ainsworth, rh Mr Bob; Morris, Grahame M. (Easington), Tellers for the Ayes: Lilian Greenwood and Gregg McClymont, Noes: Adams, Nigel; Afriyie, Adam; Aldous, Peter; Alexander, rh Danny; Davies, David T. C. (Monmouth), Tellers for the Noes: James Duddridge and Norman Lamb \n Question accordingly negatived.")
  #     
  #     NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002_p000007').returns(ncpara)
  #     ncpara.expects(:text=).with("Question put forthwith (Standing Order No. 62(2)), That the Bill be now read a Second Time.")
  #     
  #     NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002_p000008').returns(ncpara)
  #     ncpara.expects(:text=).with("Question agreed to .")
  #     
  #     NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002_p000009').returns(ncpara)
  #     ncpara.expects(:text=).with("Bill accordingly read a Second time.")
  #     
  #     @parser.parse_pages
  #   end
  # end
end
