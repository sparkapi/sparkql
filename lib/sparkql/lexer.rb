class Sparkql::Lexer < StringScanner
  include Sparkql::Token

  def initialize(str, file=nil, line=1)
    str.freeze
    super(str, false) # DO NOT dup str
    @line = line
  end
  
  def shift
    token = case
      when value = scan(SPACE)
        [:SPACE, value]
      when value = scan(OPERATOR)
        [:OPERATOR,value]
      when value = scan(CONJUNCTION)
        [:CONJUNCTION,value]
      when value = scan(STANDARD_FIELD)
        [:STANDARD_FIELD,value]
      when value = scan(DECIMAL)
        [:DECIMAL,decimal_escape(value)]
      when value = scan(INTEGER)
        [:INTEGER,integer_escape(value)]
      when value = scan(CHARACTER)
        [:CHARACTER,character_escape(value)]
      when value = scan(DATETIME)
        [:DATETIME,datetime_escape(value)]
      when value = scan(DATE)
        [:DATE,date_escape(value)]
      when value = scan(BOOLEAN)
        [:BOOLEAN,boolean_escape(value)]
      when empty?
        [false, false] # end of file, \Z don't work with StringScanner
      else
        [:UNKNOWN, "ERROR: '#{self.string}'"]
    end
    puts "TOKEN: #{token} VALUE: #{value}"
    value.freeze
    token.freeze
  end
  
  def error(msg)
    puts("Parse error: #{msg}")
  end
  
  # processes escape characters for a given string.  May be overridden by
  # child classes.
  def character_escape( string )
    string.gsub(/^\'/,'').gsub(/\'$/,'').gsub(/\\'/, "'")
  end
  
  def integer_escape( string )
    string.to_i
  end
  
  def decimal_escape( string )
    string.to_f
  end
  
  def date_escape(string)
    Date.parse(string)
  end
  
  def datetime_escape(string)
    DateTime.parse(string)
  end
  
  def boolean_escape(string)
    "true" == string
  end

end