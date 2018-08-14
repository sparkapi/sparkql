require 'strscan'

class Sparkql::Lexer < StringScanner
  include Sparkql::Token

  attr_reader :last_field, :current_token_value, :token_index

  def initialize(str)
    str.freeze
    super(str, false) # DO NOT dup str
  end

  def shift
    @token_index = self.pos

    token = case
      when @current_token_value = scan(SPACE)
        [:SPACE, @current_token_value]
      when @current_token_value = scan(LPAREN)
        [:LPAREN, @current_token_value]
      when @current_token_value = scan(RPAREN)
        [:RPAREN, @current_token_value]
      when @current_token_value = scan(/\,/)
        [:COMMA,@current_token_value]
      when @current_token_value = scan(NULL)
        literal :NULL, "NULL"
      when @current_token_value = scan(STANDARD_FIELD)
        check_standard_fields(@current_token_value)
      when @current_token_value = scan(DATETIME)
        literal :DATETIME, @current_token_value
      when @current_token_value = scan(DATE)
        literal :DATE, @current_token_value
      when @current_token_value = scan(TIME)
        literal :TIME, @current_token_value
      when @current_token_value = scan(DECIMAL)
        literal :DECIMAL, @current_token_value
      when @current_token_value = scan(INTEGER)
        literal :INTEGER, @current_token_value
      when @current_token_value = scan(CHARACTER)
        literal :CHARACTER, @current_token_value
      when @current_token_value = scan(BOOLEAN)
        literal :BOOLEAN, @current_token_value
      when @current_token_value = scan(KEYWORD)
        check_keywords(@current_token_value)
      when @current_token_value = scan(CUSTOM_FIELD)
        [:CUSTOM_FIELD, Sparkql::Nodes::CustomIdentifier.new(@current_token_value)]
      when eos?
        [false, false] # end of file, \Z don't work with StringScanner
      else
        [:UNKNOWN, "ERROR: '#{self.string}'"]
    end

    token.freeze
  end

  def check_reserved_words(value)
    u_value = value.capitalize
    if OPERATORS.include?(u_value)
      [:OPERATOR,u_value]
    elsif RANGE_OPERATOR == u_value
      [:RANGE_OPERATOR,u_value]
    elsif CONJUNCTIONS.include?(u_value)
      [:CONJUNCTION,u_value]
    elsif UNARY_CONJUNCTIONS.include?(u_value)
      [:UNARY_CONJUNCTION,u_value]
    else
      [:UNKNOWN, "ERROR: '#{self.string}'"]
    end
  end

  def check_standard_fields(value)
    result = check_reserved_words(value)
    if result.first == :UNKNOWN
      @last_field = value
      result = [:STANDARD_FIELD, Sparkql::Nodes::Identifier.new(value)]
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

  def literal(symbol, value)
    [symbol, Sparkql::Nodes::Literal.new(symbol.to_s.downcase.to_sym, value)]
  end
end
