#encoding: utf-8

require './spec/rspec_helper.rb'
require './lib/commons/debates_parser'

describe CommonsDebatesParser do
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
  
  def stub_part(house, date, part, volume)
    @daily_part = DailyPart.new
    DailyPart.stubs(:find_or_create_by).returns(@daily_part)
    @daily_part.expects(:house=).with(house)
    @daily_part.expects(:date=).with(date)
    if part
      @daily_part.stubs(:part=)
    end
    @daily_part.stubs(:persisted?)
    @daily_part.stubs(:ident)
    @daily_part.stubs(:volume=).with(volume)
    @daily_part.stubs(:save)
    @daily_part.stubs(:components).returns([])
  end
  
  context "in general" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
      stub_part("Commons", "2099-01-01", "190", "531")
      
      @component = Component.new
      @component.stubs(:sections).returns([])
      Component.stubs(:find_or_create_by).returns(@component)
      
      CommonsDebatesParser.any_instance.stubs(:house=)
      @parser = CommonsDebatesParser.new("2099-01-01")
      @parser.expects(:component_prefix).times(2).returns("d")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should pick out the timestamps" do
      stub_page("spec/data/commons/backbench_business_excerpt.html")
      
      preamble = Preamble.new
      preamble.stubs(:paragraphs).returns([])
      Preamble.stubs(:find_or_create_by).returns(preamble)
      
      paragraph = Paragraph.new
      paragraph.stubs(:member=)
      paragraph.stubs(:member).returns("test")
      
      nc = NonContributionPara.new
      nc.stubs(:section=)
      NonContributionPara.stubs(:find_or_create_by).returns(nc)
      
      cp = ContributionPara.new
      cp.stubs(:section=)
      ContributionPara.stubs(:find_or_create_by).returns(cp)
      
      div = Division.new
      div.stubs(:section=)
      Division.stubs(:find_or_create_by).returns(div)
      
      ts = Timestamp.new
      ts.stubs(:section=)
      Timestamp.stubs(:find_or_create_by).returns(ts)
      
      debate = Debate.new
      Debate.expects(:find_or_create_by).at_least_once.returns(debate)
      debate.expects(:paragraphs).at_least_once.returns([paragraph])
      
      ts.expects(:content=).with("2.44 pm")
      ts.expects(:content=).with("2.45 pm")
      
      @parser.parse
    end
  end
    
  context "when handling Backbench Business subsection" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
      stub_part("Commons", "2099-01-01", nil, "531")
      
      @component = Component.new(ident: "2099-01-01_hansard_c_d")
      @component.stubs(:sections).returns([])
      Component.stubs(:find_or_create_by).returns(@component)
      
      @parser = CommonsDebatesParser.new("2099-01-01")
      @parser.expects(:component_prefix).times(2).returns("d")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should correctly recognise the Backbench Business subsection" do
      stub_page("spec/data/commons/backbench_business_header.html")
      
      container = Container.new
      Container.expects(:find_or_create_by).returns(container)
      container.expects(:title=).with("Backbench Business")
      container.stubs(:paragraphs).returns([])
      container.expects(:sequence=).with(1)
      container.expects(:url=).with("#{@url}\#11071988000009")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).returns(ncpara)
      NonContributionPara.any_instance.stubs(:section=)
      ncpara.expects(:content=).with("[30th Allotted Day]")
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:url=).with("#{@url}\#11071988000020")
      ncpara.expects(:column=).with("831")
      ncpara.expects(:section=).with(container)
      container.paragraphs.expects(:<<).with(ncpara)
      
      @parser.parse
    end
    
    it "should handle the Preamble properly and create Debate elements for each debate" do
      stub_page("spec/data/commons/backbench_business_excerpt.html")
      
      container = Container.new(ident: "2099-01-01_hansard_c_d_000001")
      Container.expects(:find_or_create_by).returns(container)
      container.expects(:title=).with('Backbench Business')
      container.expects(:component=).with(@component)
      container.expects(:url=)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).returns(ncpara)
      NonContributionPara.any_instance.stubs(:section=)
      NonContributionPara.any_instance.stubs(:content=)
      NonContributionPara.any_instance.stubs(:sequence=)
      NonContributionPara.any_instance.stubs(:url=)
      NonContributionPara.any_instance.stubs(:column=)
      
      ncpara.expects(:content=).with("[30th Allotted Day]")
      container.paragraphs.expects(:<<).with(ncpara)
      
      debate = Debate.new
      Debate.any_instance.stubs(:paragraphs).returns([])
      Debate.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000002').returns(debate)
      debate.expects(:ident).at_least_once.returns('2099-01-01_hansard_c_d_000002')
      debate.expects(:title=).with("Summer Adjournment")
      debate.expects(:parent_section=).with(container)
      container.sections.expects(:<<).with(debate)
      
      timestamp = Timestamp.new
      Timestamp.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000002_p000001").returns(timestamp)
      timestamp.expects(:content=).with("2.44 pm")
      timestamp.expects(:column=).with("831")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000002_p000002").returns(contribution)
      contribution.expects(:content=).with("Natascha Engel (North East Derbyshire) (Lab):I beg to move,")
      contribution.expects(:column=).with("831")
      contribution.expects(:member=).with("Natascha Engel")
      contribution.expects(:speaker_printed_name=).with("Natascha Engel")
      
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000002_p000003").returns(contribution)
      contribution.expects(:content=).with("That this House has considered matters to be raised before the forthcoming adjournment.")
      contribution.expects(:column=).with("831")
      contribution.expects(:member=).with("Natascha Engel")
      
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000002_p000004").returns(contribution)
      contribution.expects(:content=).with("Thank you for calling me, Mr Deputy Speaker; I thought that this moment would never arrive. A total of 66 Members want to participate in the debate, including our newest Member - my hon. Friend the Member for Inverclyde (Mr McKenzie) - who is hoping to make his maiden speech. [Hon. Members: \"Hear, hear.\"] It is unfortunate therefore that two Government statements, important though they both were, have taken almost two hours out of Back Benchers' time. To set an example of brevity and to prepare us for all the constituency carnivals and fairs at which we will be spending most of our time during the recess, I hereby declare the debate open.")
      contribution.expects(:column=).with("831")
      contribution.expects(:member=).with("Natascha Engel")
      
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000002_p000005").returns(contribution)
      contribution.expects(:content=).with("Mr Deputy Speaker (Mr Lindsay Hoyle): We are now coming to a maiden speech, and I remind hon. Members not to intervene on it.")
      contribution.expects(:column=).with("831")
      contribution.expects(:member=).with("Lindsay Hoyle")
      contribution.expects(:speaker_printed_name=).with("Mr Deputy Speaker (Mr Lindsay Hoyle)")
      
      debate = Debate.new
      Debate.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000003').returns(debate)
      debate.expects(:title=).with('Business, innovation and skills')
      debate.expects(:ident).at_least_once.returns('2099-01-01_hansard_c_d_000003')
      debate.expects(:parent_section=).with(container)
      container.sections.expects(:<<).with(debate)
      
      Timestamp.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000003_p000001').returns(timestamp)
      timestamp.expects(:content=).with("2.45 pm")
      timestamp.expects(:column=).with("832")
      
      ContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000003_p000002').returns(contribution)
      contribution.expects(:content=).with('Mr Iain McKenzie (Inverclyde) (Lab): Thank you, Mr Deputy Speaker, for calling me in this debate to make my maiden speech. I regard it as both a privilege and an honour to represent the constituency of Inverclyde. My constituency has been served extremely well by many accomplished individuals; however, I am only the second Member for Inverclyde to have been born in Inverclyde. The first was, of course, David Cairns.')
      contribution.expects(:member=).with("Iain McKenzie")
      contribution.expects(:speaker_printed_name=).with("Mr Iain McKenzie")
      contribution.expects(:column=).with("832")
      
      ContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000003_p000003').returns(contribution)
      contribution.expects(:content=).with('My two immediate predecessors in my seat, which has often had its boundaries changed, were Dr Norman Godman and the late David Cairns. Dr Godman served in the House for 18 years, and his hard work and enduring commitment to the peace process in Northern Ireland earned him a great deal of respect and admiration. David Cairns was an excellent MP for Inverclyde; his parliamentary career was cut all too short by his sudden death, and I am well aware of the great respect that all parties had for David, as did the people of Inverclyde, as reflected in the large majority he held in the 2010 general election. If I can serve my constituents half as well as David, I shall be doing well indeed.')
      contribution.expects(:column=).with("832")
      contribution.expects(:member=).with("Iain McKenzie")
      
      @parser.parse
    end
  end
  
  context "when handling the Oral Answers subsection" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
      stub_part("Commons", "2099-01-01", nil, "531")
      
      @parser = CommonsDebatesParser.new("2099-01-01")
      @parser.expects(:component_prefix).times(2).returns("d")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should create the preamble and make a Section for Oral Answers" do
      stub_page("spec/data/commons/debates_and_oral_answers_header.html")
      HansardPage.expects(:new).returns(@page)
      
      component = Component.new
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d').returns(component)
      component.expects(:ident).at_least_once.returns('2099-01-01_hansard_c_d')
      
      preamble = Preamble.new(:ident => '2099-01-01_hansard_c_d_000001')
      Preamble.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001').returns(preamble)
      preamble.expects(:title=).with('House of Commons')
      preamble.expects(:component=).with(component)
      preamble.expects(:url=).with("#{@url}/#11071988000007")
      preamble.expects(:sequence=).with(1)
      preamble.expects(:paragraphs).at_least_once.returns([])      
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001_p000001').returns(ncpara)
      ncpara.expects(:content=).with("Tuesday 19 July 2011")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001_p000002').returns(ncpara)
      ncpara.expects(:content=).with("The House met at half-past Eleven o'clock")
      
      preamble = Preamble.new(:ident => '2099-01-01_hansard_c_d_000002')
      Preamble.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000002').returns(preamble)
      preamble.expects(:title=).with('Prayers')
      preamble.expects(:component=).with(component)
      preamble.expects(:url=).with("#{@url}/#11071988000010")
      preamble.expects(:sequence=).with(2)
      preamble.expects(:paragraphs).at_least_once.returns([])
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000002_p000001').returns(ncpara)
      ncpara.expects(:content=).with("[Mr Speaker in the Chair]")
      
      section = Container.new
      Container.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000003').returns(section)
      section.expects(:component=).with(component)
      section.expects(:title=).with("Oral Answers to Questions")
      section.expects(:url=).with("#{@url}\#11071988000008")
      section.stubs(:paragraphs).returns([])
      
      @parser.parse
    end
    
    it "should create a Question for each question found" do
      stub_page("spec/data/commons/debates_and_oral_answers.html")
      
      component = Component.new
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d').returns(component)
      component.expects(:ident).at_least_once.returns('2099-01-01_hansard_c_d')
      
      preamble = Preamble.new(ident: "2099-01-01_hansard_c_d_000001")
      Preamble.any_instance.stubs(:paragraphs).returns([])
      preamble.stubs(:content=)
      Preamble.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001').returns(preamble)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001_p000001').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001_p000002').returns(ncpara)
      
      preamble = Preamble.new(ident: "2099-01-01_hansard_c_d_000002")
      Preamble.any_instance.stubs(:paragraphs).returns([])
      preamble.stubs(:content=)
      Preamble.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000002').returns(preamble)
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000002_p000001').returns(ncpara)
      
      container = Container.new(ident: "2099-01-01_hansard_c_d_000003")
      container.expects(:title=).with("Oral Answers to Questions")
      Container.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000003').returns(container)
      
      dept_container = Container.new(ident: "2099-01-01_hansard_c_d_000004")
      Container.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000004").returns(dept_container)
      dept_container.expects(:title=).with("Foreign and Commonwealth Office")
      dept_container.expects(:parent_section=).with(container)
      container.sections.expects(:<<).with(dept_container)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000004_p000001").returns(ncpara)
      ncpara.expects(:content=).with("The Secretary of State was asked - ")
      ncpara.expects(:section=).with(dept_container)
      
      question = Question.new
      Question.any_instance.stubs(:paragraphs).returns([])
      Question.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005").returns(question)
      question.expects(:ident).at_least_once.returns("2099-01-01_hansard_c_d_000005")
      question.expects(:department=).with("Foreign and Commonwealth Office")
      question.expects(:title=).with("Syria")
      question.expects(:number=).with("66855")
      question.expects(:asked_by=).with("David Hanson")
      question.expects(:question_type=).with("for oral answer")
      question.expects(:url=).with("#{@url}\#11071988000022")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005_p000001").returns(contribution)
      contribution.expects(:content=).with("1. Mr David Hanson (Delyn) (Lab): When he next expects to discuss the situation in Syria with his US counterpart. [66855]")
      contribution.expects(:member=).with("David Hanson")
      contribution.expects(:speaker_printed_name=).with("Mr David Hanson")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005_p000002").returns(contribution)
      contribution.expects(:content=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague): I am in regular contact with Secretary Clinton and I last discussed Syria with her on Friday.")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague)")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005_p000003").returns(contribution)
      contribution.expects(:content=).with("Mr Hanson: I thank the Foreign Secretary for that answer. Given the recent violence, including the reported shooting of unarmed protesters, does he agree with Secretary of State Clinton that the Syrian Government have lost legitimacy? Given the level of violence, particularly the attacks on the US embassy and the French embassy, what steps is he taking to ensure the security of British citizens who work for the United Kingdom and are operating in Syria now?")
      contribution.expects(:member=).with("David Hanson")
      contribution.expects(:speaker_printed_name=).with("Mr Hanson")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005_p000004").returns(contribution)
      contribution.expects(:content=).with("Mr Hague: The right hon. Gentleman raises some important issues in relation to recent events in Syria. We absolutely deplore the continuing violence against protesters. Reports overnight from the city of Homs suggest that between 10 and 14 people were killed, including a 12-year-old child. We have condemned the attacks on the American and French embassies and we called in the Syrian ambassador last Wednesday to deliver our protests and to demand that Syria observes the requirements of the Vienna convention. The US and British Governments are united in saying that President Assad is losing legitimacy and should reform or step aside, and that continues to be our message.")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("Mr Hague")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005_p000005").returns(contribution)
      contribution.expects(:content=).with("Mr Philip Hollobone (Kettering) (Con): Iran has been involved in training Syrian troops and providing materi\303\251l assistance, including crowd-dispersal equipment. What assessment has the Foreign Secretary made of the dark hand of Iran in fomenting trouble in the middle east and in supporting illegitimate regimes?")
      contribution.expects(:member=).with("Philip Hollobone")
      contribution.expects(:speaker_printed_name=).with("Mr Philip Hollobone")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005_p000006").returns(contribution)
      contribution.expects(:content=).with("Mr Hague: Iran has certainly been involved in the way that my hon. Friend describes, and I set out a few weeks ago that I believed it to be involved in that way. It shows the extraordinary hypocrisy of the Iranian leadership")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("Mr Hague")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005_p000007").returns(contribution)
      contribution.expects(:content=).with("on this that it has been prepared to encourage protests in Egypt, Tunisia and other countries while it has brutally repressed protest in its own country and is prepared to connive in doing so in Syria.")
      contribution.expects(:member=).with("William Hague")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005_p000008").returns(contribution)
      contribution.expects(:content=).with("Stephen Twigg (Liverpool, West Derby) (Lab/Co-op): Does the Foreign Secretary agree that the world has been far too slow in its response to the appalling abuses of human rights in Syria? Surely, after the events of the weekend and the past few days in particular, there is now an urgent need for a clear and strong United Nations Security Council resolution.")
      contribution.expects(:member=).with("Stephen Twigg")
      contribution.expects(:speaker_printed_name=).with("Stephen Twigg")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005_p000009").returns(contribution)
      contribution.expects(:content=).with("Mr Hague: I think the world has been not so much slow as not sufficiently united on this. It has not been possible for the Arab League to arrive at a clear, strong position, which makes the situation entirely different to that in Libya, where the Arab League called on the international community to assist and intervene. There has not been the necessary unity at the United Nations Security Council and at times Russia has threatened to veto any resolution. Our resolution, which was put forward with our EU partners, remains very much on the table and certainly has the support of nine countries. We would like the support of more than nine countries to be able to put it to a vote in the Security Council, but it is very much on the table and we reserve the right at any time to press it to a vote in the United Nations. The hon. Gentleman is quite right to say that recent events add further to the case for doing so.")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("Mr Hague")
      
      question = Question.new
      Question.any_instance.stubs(:paragraphs).returns([])
      Question.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000006").returns(question)
      question.expects(:ident).at_least_once.returns("2099-01-01_hansard_c_d_000006")
      question.expects(:department=).with("Foreign and Commonwealth Office")
      question.expects(:title=).with("Nuclear Non-proliferation and Disarmament")
      question.expects(:number=).with("66858")
      question.expects(:asked_by=).with("Paul Flynn")
      question.expects(:question_type=).with("for oral answer")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000006_p000001").returns(contribution)
      contribution.expects(:content=).with("3. Paul Flynn (Newport West) (Lab): What recent progress his Department has made on nuclear non-proliferation and disarmament. [66858]")
      contribution.expects(:member=).with("Paul Flynn")
      contribution.expects(:speaker_printed_name=).with("Paul Flynn")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000006_p000002").returns(contribution)
      contribution.expects(:content=).with("The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt): We continue to work across all three pillars of the non-proliferation treaty to build on the success of last year's review conference in New York. I am particularly proud of the work we have done towards ensuring the first conference of nuclear weapon states, which was held recently in Paris - the P5 conference - in which further progress was made, particularly towards disarmament.")
      contribution.expects(:member=).with("Alistair Burt")
      contribution.expects(:speaker_printed_name=).with("The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt)")
      
      @parser.parse
    end
    
    it "should deal with the Topical Questions subsection" do
      stub_page("spec/data/commons/topical_questions.html")
      
      component = Component.new(ident: '2099-01-01_hansard_c_d')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d').returns(component)
      
      Preamble.any_instance.stubs(:paragraphs).returns([])
      
      preamble = Preamble.new(ident: "2099-01-01_hansard_c_d_000001")
      preamble.stubs(:content=)
      Preamble.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001').returns(preamble)
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001_p000001').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001_p000002').returns(ncpara)
      
      preamble = Preamble.new(ident: "2099-01-01_hansard_c_d_000002")
      preamble.stubs(:content=)
      ncpara = NonContributionPara.new
      Preamble.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000002').returns(preamble)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000002_p000001').returns(ncpara)
      
      questions_section = Container.new(ident: "2099-01-01_hansard_c_d_000003")
      Container.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000003").returns(questions_section)
      questions_section.expects(:title=).with("Oral Answers to Questions")
      
      dept_container = Container.new(ident: "2099-01-01_hansard_c_d_000004")
      Container.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000004").returns(dept_container)
      dept_container.expects(:title=).with("Foreign and Commonwealth Office")
      dept_container.expects(:parent_section=).with(questions_section)
      questions_section.sections.expects(:<<).with(dept_container)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000004_p000001").returns(ncpara)
      ncpara.expects(:content=).with("The Secretary of State was asked - ")
      ncpara.expects(:section=).with(dept_container)
      
      question = Question.new(ident: "2099-01-01_hansard_c_d_000005")
      Question.any_instance.stubs(:paragraphs).returns([])
      Question.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005").returns(question)
      question.expects(:department=).with("Foreign and Commonwealth Office")
      question.expects(:title=).with("Nuclear Non-proliferation and Disarmament")
      question.expects(:asked_by=).with("Paul Flynn")
      question.expects(:question_type=).with("for oral answer")
      question.expects(:number=).with("66858")
      question.expects(:parent_section=).with(dept_container)
      dept_container.sections.expects(:<<).with(question)
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005_p000001").returns(contribution)
      contribution.expects(:content=).with("3. Paul Flynn (Newport West) (Lab): What recent progress his Department has made on nuclear non-proliferation and disarmament. [66858]")
      contribution.expects(:member=).with("Paul Flynn")
      contribution.expects(:speaker_printed_name=).with("Paul Flynn")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005_p000002").returns(contribution)
      contribution.expects(:content=).with("The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt): We continue to work across all three pillars of the non-proliferation treaty to build on the success of last year's review conference in New York. I am particularly proud of the work we have done towards ensuring the first conference of nuclear weapon states, which was held recently in Paris - the P5 conference - in which further progress was made, particularly towards disarmament.")
      contribution.expects(:member=).with("Alistair Burt")
      contribution.expects(:speaker_printed_name=).with("The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt)")
      
      topical_section = Container.new(ident: "2099-01-01_hansard_c_d_000006")
      Container.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000006").returns(topical_section)
      topical_section.expects(:title=).with("Topical Questions")
      topical_section.expects(:url=).with("#{@url}\#11071988000034")
      topical_section.expects(:parent_section=).with(dept_container)
      dept_container.sections.expects(:<<).with(topical_section)
      
      question = Question.new(ident: "2099-01-01_hansard_c_d_000007")
      Question.any_instance.stubs(:paragraphs).returns([])
      Question.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000007").returns(question)
      question.expects(:department=).with("Foreign and Commonwealth Office")
      question.expects(:title=).with("Topical Questions - T1")
      question.expects(:number=).with("66880")
      question.expects(:asked_by=).with("Harriett Baldwin")
      question.expects(:question_type=).with("for oral answer")
      question.expects(:parent_section=).with(topical_section)
      topical_section.sections.expects(:<<).with(question)
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000007_p000001").returns(contribution)
      contribution.expects(:content=).with("T1. [66880] Harriett Baldwin (West Worcestershire) (Con): If he will make a statement on his departmental responsibilities.")
      contribution.expects(:member=).with("Harriett Baldwin")
      contribution.expects(:speaker_printed_name=).with("Harriett Baldwin")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000007_p000002").returns(contribution)
      contribution.expects(:content=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague): Statement goes here")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague)")
      
      question = Question.new(ident: "2099-01-01_hansard_c_d_000008")
      Question.any_instance.stubs(:paragraphs).returns([])
      Question.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000008").returns(question)
      question.expects(:department=).with("Foreign and Commonwealth Office")
      question.expects(:title=).with("Topical Questions - T2")
      question.expects(:asked_by=).with("Stephen Mosley")
      question.expects(:number=).with("66881")
      question.expects(:question_type=).with("for oral answer")
      question.expects(:parent_section=).with(topical_section)
      topical_section.sections.expects(:<<).with(question)
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000008_p000001").returns(contribution)
      contribution.expects(:content=).with("T2. [66881] Stephen Mosley (City of Chester) (Con): One of the remaining issues in South Sudan is that of Abyei. Will my right hon. Friend give us an update on what action is being taken to ensure that the promised referendum in Abyei goes ahead successfully?")
      contribution.expects(:member=).with("Stephen Mosley")
      contribution.expects(:speaker_printed_name=).with("Stephen Mosley")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000008_p000002").returns(contribution)
      contribution.expects(:content=).with("Mr Hague: The urgent thing has been to bring peace and order to Abyei, and that is something that I have discussed with those in the north and south in Sudan, as well as with the Ethiopian Prime Minister and Foreign Minister on my visit to Ethiopia 10 days or so ago. Up to 4,200 Ethiopian troops will go to Abyei, and we have been active in quickly passing the necessary United Nations authority for them to do so. That is designed to pave the way for political progress in Abyei, but the most urgent thing has been to get that Ethiopian force there and to prevent continuing violence.")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("Mr Hague")
      
      @parser.parse
    end
    
    it "should not treat the first Debate as another Question" do
      stub_page("spec/data/commons/topical_questions_end.html")
      
      component = Component.new(ident: '2099-01-01_hansard_c_d')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d').returns(component)
      
      preamble = Preamble.new
      Preamble.any_instance.stubs(:paragraphs).returns([])
      preamble.stubs(:content=)
      preamble.stubs(:ident).returns("2099-01-01_hansard_c_d_000001")
      Preamble.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001').returns(preamble)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001_p000001').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001_p000002').returns(ncpara)
      
      preamble = Preamble.new
      Preamble.any_instance.stubs(:paragraphs).returns([])
      preamble.stubs(:content=)
      preamble.stubs(:ident).returns("2099-01-01_hansard_c_d_000002")
      Preamble.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000002').returns(preamble)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000002_p000001').returns(ncpara)
      
      questions_section = Container.new(ident: "2099-01-01_hansard_c_d_000003")
      Container.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000003").returns(questions_section)
      questions_section.expects(:title=).with("Oral Answers to Questions")
      
      dept_section = Container.new(ident: "2099-01-01_hansard_c_d_000004")
      Container.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000004").returns(dept_section)
      dept_section.expects(:title=).with("Foreign and Commonwealth Office")
      dept_section.expects(:url=).with("#{@url}\#110719-0001.htm_dpthd0")
      
      topical_section = Container.new(ident: "2099-01-01_hansard_c_d_000005")
      Container.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000005").returns(topical_section)
      topical_section.expects(:title=).with("Topical Questions")
      topical_section.expects(:url=).with("#{@url}\#11071988000034")
      
      question = Question.new(ident: "2099-01-01_hansard_c_d_000006")
      Question.any_instance.stubs(:paragraphs).returns([])
      Question.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000006").returns(question)
      question.expects(:department=).with("Foreign and Commonwealth Office")
      question.expects(:title=).with("Topical Questions - T1")
      question.expects(:asked_by=).with("Harriett Baldwin")
      question.expects(:question_type=).with("for oral answer")
      question.expects(:number=).with("66880")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000006_p000001").returns(contribution)
      contribution.expects(:content=).with("T1. [66880] Harriett Baldwin (West Worcestershire) (Con): If he will make a statement on his departmental responsibilities.")
      contribution.expects(:member=).with("Harriett Baldwin")
      contribution.expects(:speaker_printed_name=).with("Harriett Baldwin")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000006_p000002").returns(contribution)
      contribution.expects(:content=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague): Statement goes here")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague)")
      
      debate = Debate.new(ident: "2099-01-01_hansard_c_d_000007")
      Debate.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000007").returns(debate)
      debate.stubs(:paragraphs).returns([])
      
      timestamp = Timestamp.new
      Timestamp.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000007_p000001").returns(timestamp)
      timestamp.expects(:content=).with("12.34 pm")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000007_p000002").returns(contribution)
      contribution.expects(:content=)
      contribution.expects(:member=).with("Hilary Benn")
      contribution.expects(:speaker_printed_name=).with("Hilary Benn")
      
      @parser.parse
    end
  end
    
  context "when handling a Debate containing a Division" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
      stub_part("Commons", "2099-01-01", nil, "531")
      
      @parser = CommonsDebatesParser.new("2099-01-01")
      @parser.expects(:component_prefix).times(2).returns("d")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should not handle store the Division with Ayes and Noes" do
      stub_page("spec/data/commons/debate_with_division.html")
      
      component = Component.new
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d').returns(component)
      component.expects(:ident).at_least_once.returns('2099-01-01_hansard_c_d')
      
      preamble = Preamble.new(ident: "preamble")
      Preamble.any_instance.stubs(:paragraphs).returns([])
      preamble.stubs(:content=)
      Preamble.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000001').returns(preamble)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: 'preamble_p000001').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by).with(ident: 'preamble_p000002').returns(ncpara)
      
      preamble = Preamble.new(ident: "preamble2")
      Preamble.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000002").returns(preamble)
      
      NonContributionPara.expects(:find_or_create_by).with(ident: 'preamble2_p000001').returns(ncpara)
      
      debate = Debate.new(ident: "2099-01-01_hansard_c_d_000003")
      Debate.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000003").returns(debate)
      debate.stubs(:paragraphs).returns([])
      debate.expects(:title=).with("Public Bodies Bill [Lords]")
      debate.expects(:url=).with("#{@url}\#11071272000001")
      debate.expects(:bill_title=).with("Public Bodies Bill")
      debate.expects(:bill_stage=).with("Second Reading")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000003_p000001').returns(ncpara)
      ncpara.expects(:content=).with("[Relevant documents: The Fifth Report from the Public Administration Select Committee, Smaller Government: Shrinking the Quango State, HC 537, and the Government response, Cm 8044 .]")
      
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000003_p000002').returns(ncpara)
      ncpara.expects(:content=).with("Second Reading")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000003_p000003').returns(contribution)
      contribution.expects(:content=).with("Mr Hurd: In summary, the reforms we have proposed and that have been debated again today will produce a leaner and more effective system of public bodies centred on the principle of ministerial accountability. We have listened intently to the comments and concerns expressed during the debate and recognise that there are areas where the Government can helpfully produce further clarity and assurance, and the Deputy Leader of the House and I look forward to continuing to engage with hon. Members in Committee and elsewhere.")
      
      ContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000003_p000004').returns(contribution)
      contribution.expects(:content=).with("However, I reiterate my hope that the House can come together in support of the belief that ministerial accountability for public functions and the use of public money should be at the heart of how we conduct ourselves. The Government believe that the proposals embodied in the Bill and in our plans for a regular comprehensive review of all public bodies will set a new standard for the management and review of public bodies, and on that basis I commend the Bill to the House.")
      
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000003_p000005').returns(ncpara)
      ncpara.expects(:content=).with("Question put, That the amendment be made.")
      
      division = Division.new(ident: "2099-01-01_hansard_c_d_000004", ayes: [], noes: [], tellers_ayes: [], tellers_noes: [])
      Division.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000004').returns(division)
      division.expects(:number=).with('321')
      division.expects(:ayes=).with([])
      division.expects(:noes=).with([])
      division.expects(:tellers_ayes=).with([])
      division.expects(:tellers_noes=).with([])
      division.ayes.expects(:<<).with('Abbott, Ms Diane')
      division.ayes.expects(:<<).with('Abrahams, Debbie')
      division.ayes.expects(:<<).with('Ainsworth, rh Mr Bob')
      division.ayes.expects(:<<).with('Morris, Grahame M.')
      division.ayes.expects(:pop).returns('Morris, Grahame M.')
      division.ayes.expects(:<<).with('Morris, Grahame M. (Easington)')
      
      division.noes.expects(:<<).with('Adams, Nigel')
      division.noes.expects(:<<).with('Afriyie, Adam')
      division.noes.expects(:<<).with('Aldous, Peter')
      division.noes.expects(:<<).with('Alexander, rh Danny')
      division.noes.expects(:<<).with('Davies, David T. C.')
      division.noes.expects(:pop).returns('Davies, David T. C.')
      division.noes.expects(:<<).with('Davies, David T. C. (Monmouth)')
      
      division.tellers_ayes.expects(:<<).with('Lilian Greenwood')
      division.tellers_ayes.expects(:<<).with('Gregg McClymont')
      
      division.tellers_noes.expects(:<<).with('James Duddridge')
      division.tellers_noes.expects(:<<).with('Norman Lamb')
      
      NonContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000004_p000001").returns(ncpara)
      ncpara.expects(:content=).with("The House divided:")
      
      NonContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000004_p000002").returns(ncpara)
      ncpara.expects(:content=).with("Ayes 231, Noes 307.")
      
      timestamp = Timestamp.new(ident: "2099-01-01_hansard_c_d_000004_p000003")
      Timestamp.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_d_000004_p000003").returns(timestamp)
      timestamp.expects(:content=).with("9.59 pm")
      
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000004_p000004').returns(ncpara)
      ncpara.expects(:content=).with("Question accordingly negatived.")
      
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000004_p000005').returns(ncpara)
      ncpara.expects(:content=).with("Question put forthwith (Standing Order No. 62(2)), That the Bill be now read a Second Time.")
      
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000004_p000006').returns(ncpara)
      ncpara.expects(:content=).with("Question agreed to .")
      
      NonContributionPara.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_d_000004_p000007').returns(ncpara)
      ncpara.expects(:content=).with("Bill accordingly read a Second time.")
      
      @parser.parse
    end
  end
end
