#encoding: utf-8

require "./lib/parser.rb"

class CommonsParser < Parser
  attr_reader :date, :doc_id, :house
  
  COLUMN_HEADER = /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/
  
  def initialize(date)
    super(date, "Commons")
  end
  
  
  private
  
  def process_links_and_columns(node)
    if node.attr("class") == "anchor" or node.attr("name") =~ /^\d*$/
      @last_link = node.attr("name")
    end
    
    col = set_column(node)
    @column = col if col
  end
  
  def get_member_and_column(node, process_contribution=false)
    member_name = ""
    column_desc = ""
    unless node.xpath("b").empty?
      node.xpath("b").each do |bold|
        if bold.text =~ COLUMN_HEADER #older page format
          @column = $1
          column_desc = bold.text
        else 
          member_name = bold.text.strip.squeeze(" ")
          process_member_contribution(member_name, node.text) if process_contribution
        end
      end
    end
    [member_name, column_desc]
  end
  
  def process_member_contribution(member_name, text, seq=nil, italic_text=nil)
    case member_name
    when /^(([^\(]*) \(in the Chair\):)/
      #the Chair
      name = $2
      post = "Debate Chair"
      member = HansardMember.new(name, name, "", "", post)
      handle_member_info(@member, member)
    when /^(([^\(]* [^\(]*)\) \(([^\(]*)\):)/
      #an MP speaking for the first time in the debate
      #but with a painful-for-us mistake in the online text
      name_and_constituency = $2
      party = $3
      #if we had a list of Member or Constituency names we could be clever
      #but we don't so we're going to make a horrible guess
      #this will go wrong for e.g. Mr Iain Duncan Smith
      name_words = name_and_constituency.split(" ")
      name = name_words[0..2].join(" ")
      constituency = name_and_constituency.gsub(name, "").strip
      member = HansardMember.new(name, "", constituency, party)
      handle_member_info(@member, member)
    when /^(([^\(]*) \(([^\(]*)\):)/
      #we has a minister
      post = $2
      name = $3
      member = HansardMember.new(name, "", "", "", post)
      handle_member_info(@member, member)
    when /^(([^\(]*) \(([^\(]*)\)\s?\) \(([^\(]*)\):)/,
         /^(([^\(]*) \(([^\(]*)\) \(([^\(]*)\):)/
      #an MP speaking for the first time in the debate
      name = $2
      constituency = $3
      party = $4
      member = HansardMember.new(name, "", constituency, party)
      handle_member_info(@member, member)
    when /^(([^\(]*):)/
      #an MP who's spoken before
      name = $2
      member = HansardMember.new(name, name)
      handle_member_info(@member, member)
    else
      if italic_text
        if text == "#{member_name} #{italic_text}".squeeze(" ")
          member = HansardMember.new(member_name, member_name)
          handle_member_info(@member, member)
        end
      end
    end
  end
  
  def save_section
  end
  
  def get_sequence(component_name)
    sequence = nil
    case component_name
      when "Debates and Oral Answers"
        sequence = 1
      when "Westminster Hall"
        sequence = 2
      when "Written Ministerial Statements"
        sequence = 3
      when "Petitions"
        sequence = 4
      when "Written Answers"
        sequence = 5
      when "Ministerial Corrections"
        sequence = 6
      else
        raise "unrecognised component: #{component_name}"
    end
    sequence
  end
end