require './lib/commons/parser'
require './models/hansard_page'

class WHDebatesParser < CommonsParser
  attr_reader :component, :component_prefix
  
  def initialize(date, house="Commons", component="Westminster Hall")
    super(date)
    @component = component
    @component_prefix = "wh"
  end
  
  def get_component_index
    super(component)
  end
  
  def reset_vars
    @fragment = []
  end
  
  
  private
  
  def parse_node(node, page)
    case node.name
      when "h2"
        @intro[:title] = node.content
        @intro[:link] = "#{page.url}\##{@last_link}"
      when "a"
        process_links_and_columns(node)
      when "h3"
        unless @fragment.empty?
          store_debate(page)
          @fragment = []
          @segment_link = ""
        end
        text = node.text.gsub("\n", "").squeeze(" ").strip
        fragment = HansardFragment.new
        fragment.text = sanitize_text(text)
        fragment.column = @end_column
        @fragment << fragment
        @subject = sanitize_text(text)
        @segment_link = "#{page.url}\##{@last_link}"
      when "h4"
        text = node.text.gsub("\n", "").squeeze(" ").strip
        if text[text.length-13..text.length-2] == "in the Chair"
          @chair = text[1..text.length-15]
        end
        if @intro[:title]
          @intro[:fragments] << text
          @intro[:columns] << @end_column
          @intro[:links] << "#{page.url}\##{@last_link}"
        end
      when "h5"
        fragment = HansardFragment.new
        fragment.text = node.text
        fragment.desc = "timestamp"
        fragment.column = @end_column
        fragment.link = "#{page.url}\##{@last_link}"
        @fragment << fragment
      when "p" 
        column_desc = ""
        member_name = ""
        if node.xpath("a") and node.xpath("a").length > 0
          @last_link = node.xpath("a").last.attr("name")
        end
        unless node.xpath("b").empty?
          node.xpath("b").each do |bold|
            if bold.text =~ /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/  #older page format
              if @start_column == ""
                @start_column = $1
              else
                @end_column = $1
              end
              column_desc = bold.text
            else 
              member_name = bold.text.strip
            end
          end
        else
          member_name = ""
        end
        
        text = node.content.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
        if node.xpath("i").first
          italic_text = node.xpath("i").first.content
        else
          italic_text = ""
        end
        
        if text[text.length-13..text.length-2] == "in the Chair"
          @chair = text[1..text.length-15]
        end
        
        #ignore column heading text
        unless text =~ /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/
          #check if this is a new contrib
          case member_name
            when /^(([^\(]*) \(in the Chair\):)/
              #the Chair
              name = $2
              post = "Debate Chair"
              member = HansardMember.new(name, name, "", "", post)
              handle_contribution(@member, member, page)
              @contribution_seq += 1
            when /^(([^\(]*) \(([^\(]*)\):)/
              #we has a minister
              post = $2
              name = $3
              member = HansardMember.new(name, "", "", "", post)
              handle_contribution(@member, member, page)
              @contribution_seq += 1                
            when /^(([^\(]*) \(([^\(]*)\) \(([^\(]*)\):)/
              #an MP speaking for the first time in the debate
              name = $2
              constituency = $3
              party = $4
              member = HansardMember.new(name, "", constituency, party)
              handle_contribution(@member, member, page)
              @contribution_seq += 1
            when /^(([^\(]*):)/
              #an MP who's spoken before
              name = $2
              member = HansardMember.new(name, name)
              handle_contribution(@member, member, page)                
              @contribution_seq += 1
            else
              if text == "#{member_name} #{italic_text}".squeeze(" ")
                member = HansardMember.new(member_name, member_name)
                handle_contribution(@member, member, page)
                @contribution_seq += 1
              end
          end
          
          fragment = HansardFragment.new
          fragment.text = sanitize_text(text)
          fragment.link = "#{page.url}\##{@last_link}"
          if @member
            if fragment.text =~ /^#{@member.post} \(#{@member.name}\)/
              fragment.printed_name = "#{@member.post} (#{@member.name})"
            elsif fragment.text =~ /^#{@member.search_name}/
              fragment.printed_name = @member.search_name
            else
              fragment.printed_name = @member.printed_name
            end
            fragment.speaker = @member.index_name
          end
          fragment.column = @end_column
          fragment.contribution_seq = @contribution_seq
          @fragment << fragment
        end
    end
  end
  
  def store_debate(page)
    if @intro[:title]
      @fragment_seq += 1
      intro_ident = "#{@hansard_component.ident}_#{@fragment_seq.to_s.rjust(6, "0")}"
      intro = Intro.find_or_create_by(ident: intro_ident)
      intro.title = @intro[:title]
      intro.component = @hansard_component
      intro.url = @intro[:link]
      intro.sequence = @fragment_seq
      
      @intro[:fragments].each_with_index do |fragment, i|
        @para_seq += 1
        para_ident = "#{intro.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
        
        para = NonContributionPara.find_or_create_by(ident: para_ident)
        para.fragment = intro
        para.text = fragment
        para.sequence = @para_seq
        para.url = @intro[:links][i]
        para.column = @intro[:columns][i]
        
        para.save
        intro.paragraphs << para
      end
      intro.columns = intro.paragraphs.collect{ |x| x.column }.uniq
      
      intro.save
      @hansard_component.fragments << intro
      @hansard_component.save
      
      @intro = {:fragments => [], :columns => [], :links => []}
    else
      handle_contribution(@member, @member, page)
      
      if @segment_link #no point storing pointers that don't link back to the source
        @fragment_seq += 1
        segment_ident = "#{@hansard_component.ident}_#{@fragment_seq.to_s.rjust(6, "0")}"
        
        names = []
        @members.each { |x, y| names << y.index_name unless names.include?(y.index_name) }
        
        column_text = ""
        if @start_column == @end_column or @end_column == ""
          column_text = @start_column
        else
          column_text = "#{@start_column} to #{@end_column}"
        end
        
        @debate = Debate.find_or_create_by(ident: segment_ident)
        @para_seq = 0
        @hansard_component.fragments << @debate
        @hansard_component.save
        
        @daily_part.volume = page.volume
        @daily_part.part = sanitize_text(page.part.to_s)
        @daily_part.save
        
        @debate.component = @hansard_component
        @debate.members = names
        
        @debate.title = @subject
        @debate.chair = @chair
        @debate.url = @segment_link
        
        @debate.sequence = @fragment_seq
        
        @fragment.each do |fragment|
          unless fragment.text == @debate.title or fragment.text == ""
            @para_seq += 1
            para_ident = "#{@debate.ident}_p#{@para_seq.to_s.rjust(6, "0")}"
            
            case fragment.desc
              when "timestamp"
                para = Timestamp.find_or_create_by(ident: para_ident)
              else
                if fragment.speaker.nil?
                  para = NonContributionPara.find_or_create_by(ident: para_ident)
                else
                  para = ContributionPara.find_or_create_by(ident: para_ident)
                  para.member = fragment.speaker
                  para.contribution_ident = "#{@debate.ident}__#{fragment.contribution_seq.to_s.rjust(6, "0")}"
                  if fragment.text.strip =~ /^#{fragment.printed_name.gsub('(','\(').gsub(')','\)')}/
                    para.speaker_printed_name = fragment.printed_name
                  end
                end
            end
            
            para.text = fragment.text
            para.url = fragment.link
            para.column = fragment.column
            para.sequence = @para_seq
            para.fragment = @debate
            para.save
            
            @debate.paragraphs << para
          end
        end
        
        @debate.columns = @debate.paragraphs.collect{|x| x.column}.uniq
        @debate.save
        @start_column = @end_column if @end_column != ""
        
        unless ENV["RACK_ENV"] == "test"
          p @subject
          p segment_ident
          p @segment_link
          p ""
        end
      end
    end
  end
end