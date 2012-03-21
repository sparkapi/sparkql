class Sparkql::Lexer < StringScanner
  include Sparkql::Token

  def initialize(str, value_escaper)
    str.freeze
    super(str, false) # DO NOT dup str
    @level = 0
    @block_group_identifier = 0
    @escaper = value_escaper
    @expression_count = 0
  end
  
  # Lookup the next matching token
  # 
  # TODO the old implementation did value type detection conversion at a later date, we can perform
  # this at parse time if we want!!!!
  def shift
    token = case
      when value = scan(SPACE)
        [:SPACE, value]
      when value = scan(LPAREN)
        levelup
        [:LPAREN, value]
      when value = scan(RPAREN)
        # leveldown do this after parsing group
        [:RPAREN, value]
      when value = scan(/\,/)
        [:COMMA,value]
      when value = scan(OPERATOR)
        [:OPERATOR,value]
      when value = scan(CONJUNCTION)
        [:CONJUNCTION,value]
      when value = scan(STANDARD_FIELD)
        @last_field = value
        [:STANDARD_FIELD,value]
      when value = scan(DATETIME)
      #  literal :DATETIME, datetime_escape(value)
      literal :DATETIME, value
      when value = scan(DATE)
      #  literal :DATE, date_escape(value)
      literal :DATE, value
      when value = scan(DECIMAL)
      #  literal :DECIMAL, decimal_escape(value)
      literal :DECIMAL, value
      when value = scan(INTEGER)
      #  literal :INTEGER, integer_escape(value)
      literal :INTEGER, value
      when value = scan(CHARACTER)
       # literal :CHARACTER, character_escape(value)
       literal :CHARACTER, value
      when value = scan(BOOLEAN)
#        literal :BOOLEAN, boolean_escape(value)
        literal :BOOLEAN, value
      when value = scan(KEYWORD)
        [:KEYWORD,value]
      when empty?
        [false, false] # end of file, \Z don't work with StringScanner
      else
        [:UNKNOWN, "ERROR: '#{self.string}'"]
    end
    #value.freeze
    token.freeze
  end
  
  def level
    @level
  end

  def block_group_identifier
    @block_group_identifier
  end
  
  def levelup
    @level += 1
    @block_group_identifier += 1
  end
  
  def leveldown
    @level -= 1
  end
  
  def literal(symbol, value)
    node = {
      :type => symbol.to_s.downcase.to_sym,
      :value => value
    }
    [symbol, node]
  end
  
  # processes escape characters for a given string.  May be overridden by
  # child classes.
  def character_escape( string )
    @escaper.character_escape( string )
  end
  
  def integer_escape( string )
    @escaper.integer_escape( string )
  end
  
  def decimal_escape( string )
    @escaper.decimal_escape( string )
  end
  
  def date_escape(string)
    @escaper.date_escape( string )
  end
  
  def datetime_escape(string)
    @escaper.datetime_escape( string )
  end
  
  def boolean_escape(string)
    @escaper.boolean_escape( string )
  end
  
  def last_field
    @last_field
  end
  
end