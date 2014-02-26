# Parses the grammar into a fancy markdown document.

class Markdownify
  
  def initialize file
    @file = file
    @line_num = 0
    @markdowning = false
    @codeblock = false
  end
  
  def format!
    line_num=0
    markdowning = false
    File.open(@file).each do |line|
      if line =~ /^\#STOP_MARKDOWN/
        @markdowning = false
      end
      if markdowning? && !(line =~ /^\s+$/)
        print format_line(line)
      end
      if line =~ /^\#START_MARKDOWN/
        @markdowning = true
      end
    end
    finish_code_block if @codeblock
  end
  
  def markdowning?
    @markdowning
  end
  
  def format_line(line)
    if line =~ /\s*\#/
      finish_code_block if @codeblock
      @codeblock = false
      format_doc line
    else
      start_code_block unless @codeblock
      @codeblock = true
      format_bnf line
    end
  end
  
  def format_doc line
    line.gsub(/\s+\#\s*/, '')
  end
  
  def format_bnf line
    bnf = line.gsub(/\{.+\}/, '')
    "   #{bnf}"
  end

  def start_code_block
    print "\n\n```\n"
  end
  
  def finish_code_block 
    print "```\n"
  end
end

Markdownify.new('lib/sparkql/parser.y').format!
