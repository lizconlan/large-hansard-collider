require "./lib/xml_parser"

require "./models/daily_part"
require "./models/component"
require "./models/section"
require "./models/paragraph"

class LordsDebatesXMLParser < XMLParser
  def initialize(date)
    super(date, "daylord", "./xml/lords/debates")
    @component_name = "Debates and Oral Answers"
    @section = nil
    @doc_ident = "#{date}_hansard_l"
    @date = date
    @column = ""
    @section_seq = 0
    @para_seq = 0
    @daily_part = nil 
    @hansard_component = nil
  end
  
  def parse
    start
    @doc.root.element_children.each do |node|
      case node.name
      when "major-heading"
        # p "major heading: #{node.text.strip}"
        parse_major_heading(node)
      when "minor-heading"
        # p "minor heading: #{node.text.strip}"
        parse_minor_heading(node)
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
    
    @section = create_new_debate(node.text.strip)
    @section.url = url
  end
  
  def parse_minor_heading(node)
    url = node.attributes["url"].value
    do_setup(url) unless @part
    
    @column = node.attributes["colnum"].value
    start_new_section
    
    @section = create_new_debate(node.text.strip)
    @section.url = url
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
  
  def handle_para(node, member_name=nil)
    # attrib_names = node.attributes.keys
    # if attrib_names.include?("pwmotiontext")
    #   #["asked", "agreedto", "moved", "withdrawn", "notmoved", "considered", "divided", "resumed", "unrecognized", "disagreedto"]
    #   case node.attributes["pwmotiontext"].value
    #   when "asked"
    #     type = "question"
    #   end
    # else
    #   type = "speech"
    # end
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
    section.sequence = @section_seq
    section.title = title.gsub("\n", " ").gsub("\t", " ").squeeze(" ") if title
    section.component = @hansard_component
    section
  end
  
  def save_section
    return false unless @section
    @section.append_column(@column)
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
    para.section = @section
    para.column = @column
    para.save
    
    @section.paragraphs << para
    if @section.members.nil?
      @section.members = [member_name]
    else
      @section.members << member_name unless @section.members.include?(member_name)
    end
    @section.append_column(@column)
    
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
    para.section = @section
    para.column = @column
    para.save
    @section.paragraphs << para
    @section.append_column(@column)
    para
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