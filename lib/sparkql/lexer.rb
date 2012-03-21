class Sparkql::Lexer < StringScanner
  include Sparkql::Token

  def initialize(str, value_escaper)
    str.freeze
    super(str, false) # DO NOT dup str
    @value_index = -1
    @value_prefix = "db_parser_value_"
    @level = 0
    @block_group_identifier = 0
    @escaper = value_escaper
    @expression_count = 0
  end
  
  # Lookup the next matching token
  def shift
    token = case
      when value = scan(SPACE)
        [:SPACE, value]
      when value = scan(LPAREN)
        levelup
        [:LPAREN, value]
      when value = scan(RPAREN)
        leveldown
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
        literal :DATETIME, datetime_escape(value)
      when value = scan(DATE)
        literal :DATE, date_escape(value)
      when value = scan(DECIMAL)
        literal :DECIMAL, decimal_escape(value)
      when value = scan(INTEGER)
        literal :INTEGER, integer_escape(value)
      when value = scan(CHARACTER)
        literal :CHARACTER, character_escape("'#{value}'")
      when value = scan(BOOLEAN)
        literal :BOOLEAN, boolean_escape(value)
      when empty?
        [false, false] # end of file, \Z don't work with StringScanner
      else
        [:UNKNOWN, "ERROR: '#{self.string}'"]
    end
#    puts "TOKEN: #{token.inspect}"
    value.freeze
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
  
  def error(msg)
    puts("Parse error: #{msg}")
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
  
  def next_field_key
    @value_index += 1
    @value_prefix + @value_index.to_s
  end
  
  def last_field
    @last_field
  end
  
end