require "./lib/xml_parser"

require "./models/daily_part"
require "./models/component"
require "./models/section"
require "./models/paragraph"

class LordsDebatesXMLParser < XMLParser
  attr_reader :component_name, :house
  
  def initialize(date)
    @component_name = "Debates and Oral Answers"
    @house = "Lords"
    super(date, "daylord", "./xml/lords/debates")
    @section = nil
    @doc_ident = "#{date}_hansard_l"
    @date = date
    @column = ""
    @section_seq = 0
    @para_seq = 0
    @daily_part = nil 
    @hansard_component = nil
    @in_major_section = false
    @parent = nil
    @wrapper = nil
  end
  
  def parse
    return false unless @doc
    start
    @doc.root.element_children.each do |node|
      case node.name
      when "major-heading"
        #argh, multiple things being considered together, let's split
        #those back out again
        if strip_text(node.text).split(" — ").length > 2
          headings = strip_text(node.text).split(" — ")
          headings.pop #lose the italic text - that's going to be the title
          create_sections_for_fix(node, headings)
        elsif strip_text(node.text).length > 255
          #uhoh
          fix_heading_problem(node)
        else
          if (@in_major_section and @section and @section.paragraphs.empty?) \
              and (@wrapper.nil? or (@wrapper and @wrapper.paragraphs.empty?)) \
              and !(strip_text(node.text) =~ /[A-Z][a-z]+day \d+ [A-Z][a-z]+ \d{4}/)
            #I appear to have a section immediately followed by another
            #let's assume it's a group
            unless @wrapper
              @wrapper = wrap_current_section(@section)
            end
            parse_major_heading(node)
            @section.append_column(@column, @wrapper)
            @section.parent_section = @wrapper
            @section.save
            @wrapper.save
          else
            parse_major_heading(node)
            @parent = nil
            @wrapper = nil
          end
        end
        @in_major_section = true
      when "minor-heading"
        if (strip_text(node.text) == strip_text(node.text).upcase and strip_text(node.text) =~ /AMENDMENT/) \
            or strip_text(node.text) =~ /^\[.*\]$/
          #2002, Ladies and Gentlemen - the year of the fake headings
          handle_para(node)
        elsif strip_text(node.text).split(" — ").length > 2
          headings = strip_text(node.text).split(" — ")
          headings.pop #lose the italic text - that's going to be the title
          create_sections_for_fix(node, headings)
        elsif strip_text(node.text).length > 255
          #uhoh
          fix_heading_problem(node)
        else
          parse_minor_heading(node)
        end
      when "speech"
        parse_speech(node)
      when "division"
        parse_division(node)
      else
        raise "hey, I found a #{node.name} - what should I do with it??"
      end
    end
    finish
  end
  
  def parse_major_heading(node)
    url = node.attributes["url"].value
    do_setup(url) unless @part
    
    @column = node.attributes["colnum"].value
    start_new_section
    
    text = strip_text(node.text)
    
    if text =~ /(.* Bill)( \[H\.?L\.?\])?/
      @bill_title = "#{$1}#{$2}".strip
    else
      @bill_title = nil
    end
    
    if @wrapper and node.xpath("i").text != ""
      italic_text = node.xpath("i").text
      @wrapper.title = italic_text
      if text =~ /(\s*—\s#{Regexp.escape(italic_text)}\s*$)/
        text = text.gsub($1, "")
      end
      @wrapper.save
    end
    
    if text =~ /Question$/
      @section = create_new_question(text)
    else
      @section = create_new_debate(text)
    end
    @section.url = url
    if @bill_title
      @section.bill_title = @bill_title
      @section.bill_stage = @section.title.gsub(@bill_title, "").gsub("—", "").strip
    end
  end
  
  def parse_minor_heading(node)
    if @in_major_section
      italic_text = node.xpath("i").text
      unless strip_text(node.text) =~ /^Motions? to /
        if strip_text(node.text) == italic_text
          @section.title = "#{@section.title} — #{italic_text}"
          @section.save
        else
          unless @parent or @wrapper
            @section.type = "Container"
            @parent = @section.dup
          end
          parse_major_heading(node)
          @section.parent_section = @parent
          @parent.sections << @section
          @parent.save
        end
      else
        if @wrapper and node.xpath("i").text != ""
          @wrapper.title = node.xpath("i").text
          @wrapper.save
        end
      end
    else
      parse_major_heading(node)
    end
  end
  
  def parse_division(node)
    @column = node.attributes["colnum"].value
    division_number = node.attributes["divnumber"].value
    url = node.attributes["url"].value
    #divisioncount
    #lordlist -> attributes["vote"] => content / notcontent
      #lord -> attributes["id"], attributes["vote"] (as above) | text => "Aberdare, L."
    #lordlist -> 
    p "<< ignoring divisions, for now >>"
  end
  
  def parse_speech(node)
    @column = node.attributes["colnum"].value
    speaker = nil
    if node.attributes["speakername"]
      speaker = node.attributes["speakername"].value
    end
    paragraphs = node.xpath("p")
    paragraphs.each do |para|
      handle_para(para, speaker)
    end
  end
  
  def wrap_current_section(current_section)
    wrapper_ident = current_section.ident
    wrapper_sequence = current_section.sequence
    
    @section_seq +=1
    current_section.ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    current_section.sequence = @section_seq
    current_section.save
    
    wrapper = SectionGroup.find_or_create_by(ident: wrapper_ident)
    wrapper.columns = [@column]
    wrapper.url = current_section.url
    wrapper.sequence = wrapper_sequence
    wrapper.component = @hansard_component
    wrapper.save
    
    current_section.parent_section = wrapper
    current_section.save
    
    wrapper.sections << current_section
    wrapper.members = []
    wrapper
  end
  
  def handle_para(node, member_name=nil)
    if @section.title == strip_text(node.text)
      return false
    end
    if member_name
      para = create_new_contribution_para(node.text, member_name)
    else
      para = create_new_noncontribution_para(node.text)
    end
  end
  
  def do_setup(url)
    scrape_metadata(url)
    @daily_part = DailyPart.find_or_create_by(ident: @doc_ident)
    @daily_part.house = "lords"
    @daily_part.date = @date
    @daily_part.volume = @volume
    @daily_part.part = @part
    
    @hansard_component = create_component
    @section_seq = 0
    @daily_part.components << @hansard_component
    @daily_part.save
  end
  
  def create_component
    component_ident = "#{@doc_ident}_d"
    component = Component.find_or_create_by(ident: component_ident)
    component.daily_part = @daily_part
    component.sequence = get_sequence(@component_name)
    component.name = @component_name
    component.save
    component
  end
  
  def create_new_debate(title=nil)
    @section_seq +=1
    section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    section = Debate.find_or_create_by(ident: section_ident)
    section.members = []
    section.columns = [@column]
    section.sequence = @section_seq
    section.title = title.gsub(/\d{1,2}\.\d{2}\s(?:a|p)m/, "").strip if title
    section.component = @hansard_component
    section
  end
  
  def create_new_question(title=nil)
    @section_seq +=1
    section_ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    section = Question.find_or_create_by(ident: section_ident)
    section.members = []
    section.columns = [@column]
    section.sequence = @section_seq
    section.title = title.gsub(/\d{1,2}\.\d{2}\s(?:a|p)m/, "").strip if title
    section.component = @hansard_component
    section
  end
  
  def save_section
    return false unless @section
    if @section.columns.count > 2
      @section.columns = [@section.columns.first, @section.columns.last]
    end
    
    @section.save
    print_debug(@section)
  end
  
  def get_sequence(component_name)
    sequence = nil
    case component_name
      when "Debates and Oral Answers"
        sequence = 1
      when "Grand Committee"
        sequence = 2
      when "Written Statements"
        sequence = 3
      when "Written Answers"
        sequence = 4
      else
        raise "unrecognised component: #{component_name}"
    end
    sequence
  end
  
  def create_new_contribution_para(text, member_name="", ident=nil)
    stored_name = ""
    unless ident
      @para_seq += 1
      ident = "#{@section.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
    end
    para = ContributionPara.find_or_create_by(ident: ident)
    para.content = text.gsub("\n", " ").gsub("\t", " ").squeeze(" ")
    para.speaker_printed_name = member_name
    para.sequence = @para_seq
    if @wrapper
      para.section = @wrapper
    else
      para.section = @section
    end
    para.column = @column
    para.save
    
    if @wrapper
      @wrapper.paragraphs << para
      unless member_name == "Noble Lords"
        if @wrapper.members.nil?
          @wrapper.members = [member_name]
        else
          @wrapper.members << member_name unless @wrapper.members.include?(member_name)
        end
      end
      @wrapper.append_column(@column)
    else
      @section.paragraphs << para
      unless member_name == "Noble Lords"
        if @section.members.nil?
          @section.members = [member_name]
        else
          @section.members << member_name unless @section.members.include?(member_name)
        end
      end
      @section.append_column(@column)
    end
    
    para
  end
  
  def create_new_noncontribution_para(text, ident=nil)
    unless ident
      @para_seq += 1
      ident = "#{@section.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
    end
    
    para = NonContributionPara.find_or_create_by(ident: ident)
    para.content = text.gsub("\n", " ").gsub("\t", " ").squeeze(" ")
    para.sequence = @para_seq
    if @wrapper
      para.section = @wrapper
    else
      para.section = @section
    end
    para.column = @column
    para.save
    
    if @wrapper
      @wrapper.paragraphs << para
      @wrapper.append_column(@column)
    else
      @section.paragraphs << para
      @section.append_column(@column)
    end
    para
  end
  
  def fix_heading_problem(node)
    text = strip_text(node.text)
    #look for a known specific problem - this one's a Hansard web issue, not an XML problem
    case text
    when "Intelligence and Security Committee: Annual ReportCompanies Act 2006 (Accounts, Reports and Audit) Regulations 2009 Registrar of Companies and Applications for Striking Off Regulations 2009 Overseas Companies Regulations 2009 Limited Liability Partnerships (Application of Companies Act 2006) Regulations 2009 Companies Act 2006 (Part 35) (Consequential Amendments, Transitional Provisions and Savings) Order 2009 — Motion to Refer to Grand Committee"
      
      headings = []
      headings << "Intelligence and Security Committee: Annual Report"
      headings << "Companies Act 2006 (Accounts, Reports and Audit) Regulations 2009"
      headings << "Registrar of Companies and Applications for Striking Off Regulations 2009"
      headings << "Overseas Companies Regulations 2009"
      headings << "Limited Liability Partnerships (Application of Companies Act 2006) Regulations 2009"
      headings << "Companies Act 2006 (Part 35) (Consequential Amendments, Transitional Provisions and Savings) Order 2009"
      
      create_sections_for_fix(node, headings)
    else
      p text
      raise "title too long - please code a manual fix"
    end
  end
  
  def create_sections_for_fix(node, headings)
    title = node.xpath("i").text.gsub(/\d{1,2}\.\d{2}\s(?:a|p)m/, "").strip
    start_new_section
    @section_seq +=1
    ident = "#{@hansard_component.ident}_#{@section_seq.to_s.rjust(6, "0")}"
    @section = SectionGroup.find_or_create_by(ident: ident)
    @section.component = @hansard_component
    @section.title = title
    @section.url = node.attributes["url"].value
    @section.sequence = @section_seq
    @section.members = []
    @section.columns = [@column]
    @section.save
    @wrapper = @section.dup
    
    headings.each do |heading|
      start_new_section
      @section = create_new_debate(heading)
      @section.parent_section = @wrapper
      @wrapper.sections << @section
      @section.save
      @wrapper.save
    end
  end
  
  def print_debug(section)
    unless ENV["RACK_ENV"] == "test"
      p section.title
      p section.ident
      p section.url
      p section.members
      p section.columns
      p ""
    end
  end
end