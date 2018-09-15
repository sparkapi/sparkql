# frozen_string_literal: true

require 'test_helper'

class LexerTest < Test::Unit::TestCase
  include Sparkql

  test 'record the current token and current oken position' do
    @lexer = Lexer.new "City Eq 'Fargo'"
    token = @lexer.shift
    assert_equal 'City', @lexer.current_token_value
    assert_equal 0, @lexer.token_index

    token = @lexer.shift
    assert_equal ' ', @lexer.current_token_value
    assert_equal 4, @lexer.token_index

    token = @lexer.shift
    assert_equal 'Eq', @lexer.current_token_value
    assert_equal 5, @lexer.token_index
  end

  def test_check_reserved_words_standard_fields
    ['OrOrOr Eq true', 'Equador Eq true', 'Oregon Ge 10'].each do |standard_field|
      @lexer = Lexer.new(standard_field)
      token = @lexer.shift
      assert_equal :STANDARD_FIELD, token.first, standard_field
    end
  end

  def test_standard_field_formats
    %w[City PostalCodePlus4 Inb4ParserError].each do |standard_field|
      @lexer = Lexer.new("#{standard_field} Eq true")
      token = @lexer.shift
      assert_equal :STANDARD_FIELD, token.first, standard_field
      assert_equal standard_field, token.last['value']
    end
  end

  def test_bad_standard_field_formats
    @lexer = Lexer.new('4PostalCodePlus4 Eq true')
    token = @lexer.shift
    assert_equal :INTEGER, token.first
    assert_equal 4, token.last['value']
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

    ['Bt 1234', 'Bt 1234,12345'].each do |op|
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

  def test_dates_matches
    ['2013-07-26', '1999-01-01'].each do |op|
      @lexer = Lexer.new(op)
      token = @lexer.shift
      assert_equal :DATE, token.first, op
    end
  end

  def test_times_matches
    ['10:22:15.422804', '10:22:15', '10:22'].each do |op|
      @lexer = Lexer.new(op)
      token = @lexer.shift
      assert_equal :TIME, token.first, op
    end
  end

  def test_utc_offsets
    ['2013-07-26T10:22:15.422804-0300', '2013-07-26T10:22:15+0400'].each do |op|
      @lexer = Lexer.new(op)
      token = @lexer.shift
      assert_equal :DATETIME, token.first, op
    end
  end

  def test_decimal_matches
    ['-15.42', '1.0', '0.22', '9.0E-6', '-9.0E-3'].each do |op|
      @lexer = Lexer.new(op)
      token = @lexer.shift
      assert_equal :DECIMAL, token.first, op
    end
  end
end
