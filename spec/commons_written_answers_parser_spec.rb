# encoding: UTF-8

require './spec/rspec_helper.rb'
require './lib/commons/written_answers_parser'

describe WrittenAnswersParser do
  def stub_saves
    Preamble.any_instance.stubs(:save)
    NonContributionPara.any_instance.stubs(:save)
    ContributionPara.any_instance.stubs(:save)
    ContributionTable.any_instance.stubs(:save)
    Component.any_instance.stubs(:save)
    DailyPart.any_instance.stubs(:save)
    Question.any_instance.stubs(:save)
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
  
  context "in general" do
    before(:each) do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/text/110719w0001.htm"
      stub_saves
      stub_daily_part
      
      @parser = WrittenAnswersParser.new("2099-01-01")
      @parser.stubs(:component_prefix).returns("w")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should create the Preamble section" do
      stub_page("spec/data/commons/written_answers.html")
      HansardPage.expects(:new).returns(@page)
      
      component = Component.new(:ident => '2099-01-01_hansard_c_w')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_w').returns(component)
      
      preamble = Preamble.new(:ident => "2099-01-01_hansard_c_w_000001")
      Preamble.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_w_000001").returns(preamble)
      preamble.expects(:title=).with("Written Answers to Questions")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_w_000001_p000001").returns(ncpara)
      ncpara.expects(:section=).with(preamble)
      ncpara.expects(:content=).with("Tuesday 19 July 2011")
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:url=).with("#{@url}\#110719112000009")
      ncpara.expects(:column=).with("773W")
      
      preamble.expects(:paragraphs).at_least_once.returns([ncpara])
      
      #ignore the rest of the file, not relevant
      contribution = ContributionPara.new
      question = Question.new(:ident => "question")
      
      ContributionPara.expects(:find_or_create_by).at_least_once.returns(contribution)
      
      Question.expects(:find_or_create_by).at_least_once.returns(question)
      
      @parser.parse
    end
    
    it "should create the Question sections" do
      stub_page("spec/data/commons/written_answers.html")
      HansardPage.expects(:new).returns(@page)
      
      component = Component.new(:ident => '2099-01-01_hansard_c_w')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_w').returns(component)
      
      preamble = Preamble.new(:ident => "preamble")
      Preamble.any_instance.stubs(:paragraphs).returns([])
      Preamble.any_instance.stubs(:title=)
      Preamble.expects(:find_or_create_by).returns(preamble)
      
      ncpara = NonContributionPara.new
      NonContributionPara.any_instance.stubs(:paragraphs).returns([])
      NonContributionPara.stubs(:content=)
      NonContributionPara.expects(:find_or_create_by).returns(ncpara)
      
      question = Question.new(:ident => "2099-01-01_hansard_c_w_000002")
      Question.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_w_000002").returns(question)
      question.expects(:paragraphs).at_least_once.returns([])
      question.expects(:number=).with("67391")
      question.expects(:component=).with(component)
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_w_000002_p000001").returns(contribution)
      contribution.expects(:section=).with(question)
      contribution.expects(:content=).with('Mr Leigh: To ask the hon. Member for Caithness, Sutherland and Easter Ross, representing the House of Commons Commission when the House of Commons Commission will respond to the First Report of the Administration Committee, Session 2010-12, on Catering and Retail Services in the House of Commons, HC 560; and if he will make a statement. [67391]')
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(1)
      contribution.expects(:column=)
      contribution.expects(:member=).with("Mr Leigh")
      contribution.expects(:speaker_printed_name=).with("Mr Leigh")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_w_000002_p000002").returns(contribution)
      contribution.expects(:section=).with(question)
      contribution.expects(:content=).with("John Thurso: The Commission welcomes the Administration Committee's report on Catering and Retail Services in the House of Commons and is grateful to the Committee for its work. The Commission agrees with most of the recommendations, including all those which the Management Board has recommended be accepted. It has asked that the remainder be discussed with the Committee by officials of the House Service, after which the Commission will consider them again. That is expected to be in September.")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(2)
      contribution.expects(:member=).with("John Thurso")
      contribution.expects(:column=)
      
      question = Question.new(:ident => "2099-01-01_hansard_c_w_000003")
      Question.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_w_000003').returns(question)
      question.expects(:paragraphs).at_least_once.returns([])
      question.expects(:number=).with("67110")
      question.expects(:component=).with(component)
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_w_000003_p000001").returns(contribution)
      contribution.expects(:section=).with(question)
      contribution.expects(:content=).with('Priti Patel: To ask the hon. Member for Caithness, Sutherland and Easter Ross, representing the House of Commons Commission pursuant to the answer of 1 December 2010, Official Report, column 824W, on smartphone applications, what recent progress has been made in the development of smartphone applications for Parliament. [67110]')
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(1)
      contribution.expects(:column=)
      contribution.expects(:member=).with("Priti Patel")
      contribution.expects(:speaker_printed_name=).with("Priti Patel")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_w_000003_p000002").returns(contribution)
      contribution.expects(:section=).with(question)
      contribution.expects(:content=).with("John Thurso: The development of a smartphone application, designed primarily for those visiting Parliament, has been halted. The quotes received from the procurement exercise were too expensive and it has been decided not to continue at this stage. Further work will be undertaken in due course to explore a more cost-effective method of providing visitor information via smartphones.")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(2)
      contribution.expects(:member=).with("John Thurso")
      contribution.expects(:column=)
      
      question = Question.new(:ident => '2099-01-01_hansard_c_w_000004')
      Question.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_w_000004').returns(question)
      question.expects(:paragraphs).at_least_once.returns([])
      question.expects(:number=).with("67046")
      question.expects(:component=).with(component)
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_w_000004_p000001").returns(contribution)
      contribution.expects(:section=).with(question)
      contribution.expects(:content=).with('Mr Bain: To ask the Secretary of State for the Home Department how many places in Scotland were designated as a (a) supplying establishment, (b) breeding establishment and (c) scientific procedure establishment under the Animals (Scientific Procedures) Act 1986 at the end of 2010. [67046]')
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(1)
      contribution.expects(:column=)
      contribution.expects(:member=).with("Mr Bain")
      contribution.expects(:speaker_printed_name=).with("Mr Bain")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_w_000004_p000002").returns(contribution)
      contribution.expects(:section=).with(question)
      contribution.expects(:content=).with("Lynne Featherstone: As at 31 December 2010, there were 32 establishments in Scotland designated as scientific procedure establishments under the Animals (Scientific Procedures) Act 1986. Of these, 13 were also designated as breeding establishments and 19 as supplying establishments.")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(2)
      contribution.expects(:member=).with("Lynne Featherstone")
      contribution.expects(:column=)
      
      @parser.parse
    end
  end
    
  context "when dealing with edge cases" do
    before(:all) do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/text/110719w0001.htm"
      stub_saves
      stub_daily_part
      
      @parser = WrittenAnswersParser.new("2099-01-01")
      @parser.stubs(:component_prefix).returns("w")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should handle tables without escaping the markup" do
      html = %Q|<div id="content-small">
        <a class="anchor" name="11071988000009"></a>
        <a class="anchor-column" name="column_831W"></a>
        <a class="anchor" name="dpthd_2"> </a>
        <a class="anchor" name="110719112000002"> </a>
        <a class="anchor" name="110719w0001.htm_dpthd0"> </a>
        <h3 style="text-transform:uppercase">House of Commons Commission</h3>
        <a class="anchor" name="subhd_48"> </a>
        <a class="anchor" name="110719w0001.htm_sbhd0"> </a>
        <a class="anchor" name="110719112000010"> </a>
        <h3 align="center">Catering</h3>
        <p>
           <a class="anchor" name="qn_0"> </a>
           <a class="anchor" name="110719w0001.htm_wqn0"> </a>
           <a class="anchor" name="110719112000085"> </a>
           <a class="anchor" name="110719112001598"> </a>
           <b>Mr Leigh:</b>
           Question goes here [0123456]
        </p>
        <table border="1">
          <tbody>
          <tr valign="top">
            <td>Heading 1</td>
            <td class="tabletext">They don't use TH so neither can I</td>
          </tr>
          <tr>
            <td>Ukraine</td>
            <td>>£1,000</td>
          </tr>
          </tbody>
        </table>
      </div>|
      stub_page("", html)
      HansardPage.expects(:new).returns(@page)
      
      component = Component.new(:ident => '2099-01-01_hansard_c_w')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_w').returns(component)
      
      question = Question.new(:ident => "question")
      Question.expects(:find_or_create_by).returns(question)
      question.expects(:department=).with('House of Commons Commission')
      question.expects(:title=).with('Catering')
      question.expects(:question_type=).with("for written answer")
      question.expects(:paragraphs).at_least_once.returns([])
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "question_p000001").returns(contribution)
      contribution.expects(:member=).with("Mr Leigh")
      
      contrib_table = ContributionTable.new
      ContributionTable.expects(:find_or_create_by).with(ident: "question_p000002").returns(contrib_table)
      
      @parser.parse
    end
  end
end
