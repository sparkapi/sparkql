require 'test_helper'

class LexerTest < Test::Unit::TestCase
  include Sparkql
  
  def test_check_reserved_words_standard_fields
    ["OrOrOr Eq true", "Equador Eq true", "Oregon Ge 10"].each do |standard_field|
      @lexer = Lexer.new(standard_field)
      token = @lexer.shift
      assert_equal :STANDARD_FIELD, token.first, standard_field
    end
  end
  def test_check_reserved_words_conjunctions
    ['And Derp', 'Or 123'].each do |conjunction|
      @lexer = Lexer.new(conjunction)
      token = @lexer.shift
      assert_equal :CONJUNCTION, token.first, conjunction
    end
    ['Not Lol'].each do |conjunction|
      @lexer = Lexer.new(conjunction)
      token = @lexer.shift
      assert_equal :UNARY_CONJUNCTION, token.first, conjunction
    end
  end

  def test_check_reserved_words_operators
    ['Eq Derp', 'Gt 123'].each do |op|
      @lexer = Lexer.new(op)
      token = @lexer.shift
      assert_equal :OPERATOR, token.first, op
    end

    ['Bt 1234','Bt 1234,12345'].each do |op|
      @lexer = Lexer.new(op)
      token = @lexer.shift
      assert_equal :RANGE_OPERATOR, token.first, op
    end
  end

  def test_datetimes_matches
    ['2013-07-26T10:22:15.422804', '2013-07-26T10:22:15'].each do |op|
      @lexer = Lexer.new(op)
      token = @lexer.shift
      assert_equal :DATETIME, token.first, op
    end
  end
      
end
