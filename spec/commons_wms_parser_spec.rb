# encoding: UTF-8

require './spec/rspec_helper.rb'
require './lib/commons/wms_parser'

describe WMSParser do
  def stub_saves
    Preamble.any_instance.stubs(:save)
    NonContributionPara.any_instance.stubs(:save)
    ContributionPara.any_instance.stubs(:save)
    ContributionTable.any_instance.stubs(:save)
    Component.any_instance.stubs(:save)
    DailyPart.any_instance.stubs(:save)
    Statement.any_instance.stubs(:save)
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
        @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/wmstext/110719m0001.htm"
        stub_saves
        stub_daily_part
        
        @parser = WMSParser.new("2099-01-01")
        @parser.stubs(:component_prefix).returns("wms")
        @parser.expects(:link_to_first_page).returns(@url)
      end
      
      it "should create the Preamble section" do
        stub_page("spec/data/commons/wms.html")
        HansardPage.expects(:new).returns(@page)
        
        component = Component.new(:ident => '2099-01-01_hansard_c_wms')
        Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wms').returns(component)
        
        preamble = Preamble.new(:ident => "2099-01-01_hansard_c_wms_000001")
        Preamble.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wms_000001").returns(preamble)
        preamble.expects(:title=).with("Written Ministerial Statements")
        
        ncpara = NonContributionPara.new
        NonContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wms_000001_p000001").returns(ncpara)
        ncpara.expects(:section=).with(preamble)
        ncpara.expects(:content=).with("Tuesday 19 July 2011")
        ncpara.expects(:sequence=).with(1)
        ncpara.expects(:url=).with("#{@url}\#11071985000016")
        ncpara.expects(:column=).with("89WS")
        
        preamble.expects(:paragraphs).at_least_once.returns([ncpara])
        
        #ignore the rest of the file, not relevant
        statement = Statement.new
        statement.stubs(:paragraphs).returns([])
        contribution = ContributionPara.new
        Statement.expects(:find_or_create_by).at_least_once.returns(statement)
        
        ContributionPara.expects(:find_or_create_by).at_least_once.returns(contribution)
        contribution.expects(:section=).at_least_once
        contribution.expects(:content=).at_least_once
        contribution.expects(:url=).at_least_once
        contribution.expects(:sequence=).at_least_once
        contribution.expects(:column=).at_least_once
        contribution.expects(:member=).at_least_once
        contribution.expects(:speaker_printed_name=).at_least_once
        
        @parser.parse
      end
      
      it "should create the Statement sections" do
        stub_page("spec/data/commons/wms.html")
        HansardPage.expects(:new).returns(@page)
        
        component = Component.new(:ident => '2099-01-01_hansard_c_wms')
        Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wms').returns(component)
        
        preamble = Preamble.new(:ident => "preamble")
        Preamble.any_instance.stubs(:paragraphs).returns([])
        Preamble.expects(:find_or_create_by).returns(preamble)
        
        ncpara = NonContributionPara.new
        NonContributionPara.any_instance.stubs(:paragraphs).returns([])
        NonContributionPara.stubs(:content=)
        NonContributionPara.expects(:find_or_create_by).returns(ncpara)
        ncpara.expects(:section=).with(preamble)
        
        statement = Statement.new(:ident => "2099-01-01_hansard_c_wms_000002")
        Statement.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wms_000002").returns(statement)
        statement.expects(:department=).with("Justice")
        statement.expects(:title=).with("Secure Estate Strategy for Children and Young People")
        statement.expects(:paragraphs).at_least_once.returns([])
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wms_000002_p000001").returns(contribution)
        contribution.expects(:section=).with(statement)
        contribution.expects(:content=).with('The Parliamentary Under-Secretary of State for Justice (Mr Crispin Blunt):Today is the launch of a consultation on the "Strategy for the Secure Estate for Children and Young People for England and Wales".')
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(1)
        contribution.expects(:column=)
        contribution.expects(:member=).with("Crispin Blunt")
        contribution.expects(:speaker_printed_name=).with("The Parliamentary Under-Secretary of State for Justice (Mr Crispin Blunt)")
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wms_000002_p000002").returns(contribution)
        contribution.expects(:section=).with(statement)
        contribution.expects(:content=).with('This is a joint publication between the Ministry of Justice and the Youth Justice Board. The consultation invites views on a proposed strategy for the under-18 secure estate for the years 2011-12 to 2014-15. Custody continues to play an important part in the youth justice system for the small number of young people for whom a community sentence is not appropriate. The recent reduction in the number of young people in custody means that the secure estate is now going through a period of change. This presents an opportunity to consider the most appropriate configuration of the estate and consider whether different regimes can deliver improved outcomes.')
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(2)
        contribution.expects(:column=)
        contribution.expects(:member=).with("Crispin Blunt")
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wms_000002_p000003").returns(contribution)
        contribution.expects(:section=).with(statement)
        contribution.expects(:content=).with('The consultation, which will run for 12 weeks, and details on how to respond can be found on the Ministry of Justice website at www.justice.gov.uk.')
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(3)
        contribution.expects(:column=)
        contribution.expects(:member=).with("Crispin Blunt")
        
        statement = Statement.new(:ident => "2099-01-01_hansard_c_wms_000003")
        Statement.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wms_000003").returns(statement)
        statement.expects(:department=).with("Justice")
        statement.expects(:title=).with("Deaths of Service Personnel Overseas (Inquests)")
        statement.expects(:paragraphs).at_least_once.returns([])
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wms_000003_p000001").returns(contribution)
        contribution.expects(:section=).with(statement)
        contribution.expects(:content=).with("The Parliamentary Under-Secretary of State for Justice (Mr Jonathan Djanogly):My hon. friend the Minister for the Armed Forces and I wish to make the latest of our quarterly statements to the House with details of the inquests of service personnel who have died overseas. As always, we wish to express the Government's deep")
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(1)
        contribution.expects(:member=).with("Jonathan Djanogly")
        contribution.expects(:speaker_printed_name=).with("The Parliamentary Under-Secretary of State for Justice (Mr Jonathan Djanogly)")
        contribution.expects(:column=)
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wms_000003_p000002").returns(contribution)
        contribution.expects(:section=).with(statement)
        contribution.expects(:content=).with("and abiding gratitude to all of our service personnel who have served, or are now serving, in Iraq and Afghanistan.")
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(2)
        contribution.expects(:member=).with("Jonathan Djanogly")
        contribution.expects(:column=)
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by).with(ident: "2099-01-01_hansard_c_wms_000003_p000003").returns(contribution)
        contribution.expects(:section=).with(statement)
        contribution.expects(:content=).with("Once again we also extend our sincere condolences to the families of those service personnel who have made the ultimate sacrifice for their country in connection with the operations in Iraq and Afghanistan, and in particular the 11 service personnel who have died since our last statement. Our thoughts remain with all of the families.")
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(3)
        contribution.expects(:member=).with("Jonathan Djanogly")
        contribution.expects(:column=).with("109WS")
        
        @parser.parse
      end
    end
    
  context "when dealing with edge cases" do
    before(:all) do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/text/110719w0001.htm"
      stub_saves
      stub_daily_part
      
      @parser = WMSParser.new("2099-01-01")
      @parser.stubs(:component_prefix).returns("wms")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should handle tables without escaping the markup" do
      html = %Q|<div id="content-small">
        <a class="anchor" name="11071988000009"></a>
        <a class="anchor-column" name="column_831"></a>
        <a class="anchor" name="subhd_30"> </a>
        <a class="anchor" name="11071985000011"> </a>
        <a class="anchor" name="110719m0001.htm_dpthd9"> </a>
        <h3 style="text-transform:uppercase">House of Commons Commission</h3>
        <a class="anchor" name="subhd_31"> </a>
        <a class="anchor" name="110719m0001.htm_sbhd21"> </a>
        <a class="anchor" name="11071985000038"> </a>
        <h4 align="center">Catering</h4>
        
        <p>
           <a class="anchor" name="st_166"> </a>
           <a class="anchor" name="11071985000590"> </a>
           <a class="anchor" name="110719m0001.htm_spmin21"> </a>
           <a class="anchor" name="11071985000898"> </a>
           <b>Mr Crispin Blunt:</b>
           Statement goes here</p>
        <table border="1">
          <tbody>
          <tr valign="top">
            <td>Heading 1</td>
            <td class="tabletext"><a class="anchor" name="11071985000898"> </a>They don't use TH so neither can I</td>
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
      
      component = Component.new(:ident => '2099-01-01_hansard_c_wms')
      Component.expects(:find_or_create_by).with(ident: '2099-01-01_hansard_c_wms').returns(component)
      
      statement = Statement.new(:ident => "statement")
      Statement.expects(:find_or_create_by).returns(statement)
      statement.expects(:department=).with('House of Commons Commission')
      statement.expects(:title=).with('Catering')
      statement.expects(:paragraphs).at_least_once.returns([])
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by).with(ident: "statement_p000001").returns(contribution)
      contribution.expects(:member=).with("Crispin Blunt")
      
      contrib_table = ContributionTable.new
      ContributionTable.expects(:find_or_create_by).with(ident: "statement_p000002").returns(contrib_table)
      
      @parser.parse
    end
  end

end
