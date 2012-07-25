class Sparkql::Lexer < StringScanner
  include Sparkql::Token

  def initialize(str)
    str.freeze
    super(str, false) # DO NOT dup str
    @level = 0
    @block_group_identifier = 0
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
      when value = scan(STANDARD_FIELD)
        check_standard_fields(value)
      when value = scan(DATETIME)
        literal :DATETIME, value
      when value = scan(DATE)
        literal :DATE, value
      when value = scan(DECIMAL)
        literal :DECIMAL, value
      when value = scan(INTEGER)
        literal :INTEGER, value
      when value = scan(CHARACTER)
        literal :CHARACTER, value
      when value = scan(BOOLEAN)
        literal :BOOLEAN, value
      when value = scan(KEYWORD)
        check_keywords(value)
      when value = scan(CUSTOM_FIELD)
        [:CUSTOM_FIELD,value]
      when empty?
        [false, false] # end of file, \Z don't work with StringScanner
      else
        [:UNKNOWN, "ERROR: '#{self.string}'"]
    end
    #value.freeze
    token.freeze
  end
  
  def check_reserved_words(value)
    u_value = value.capitalize
    if OPERATORS.include?(u_value)
      [:OPERATOR,u_value]
    elsif CONJUNCTIONS.include?(u_value)
      [:CONJUNCTION,u_value]
    else
      [:UNKNOWN, "ERROR: '#{self.string}'"]
    end
  end
  
  def check_standard_fields(value)
    result = check_reserved_words(value)
    if result.first == :UNKNOWN
      @last_field = value
      result = [:STANDARD_FIELD,value]
    end
    result
  end

  def check_keywords(value)
    result = check_reserved_words(value)
    if result.first == :UNKNOWN
      result = [:KEYWORD,value]
    end
    result
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
  
  def last_field
    @last_field
  end
  
end