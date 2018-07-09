require 'test_helper'

class ParserTest < Test::Unit::TestCase
  include Sparkql

  def test_not_expression
    @parser = Parser.new
    expressions = @parser.parse('Test Lt 10 Not Test Eq 2')
    assert !@parser.errors?, @parser.inspect
    expression = expressions.last
    assert_equal 2.to_s, expression[:value]
    assert_equal "Not", expression[:conjunction]
    assert_equal expression[:level], expression[:conjunction_level]
  end

  def test_not_unary_expression
    @parser = Parser.new
    expressions = @parser.parse('Not Test Eq 10')
    assert !@parser.errors?, @parser.inspect
    expression = expressions.first
    assert_equal 10.to_s, expression[:value]
    assert_equal "Not", expression[:unary]
    assert_equal "And", expression[:conjunction]
    assert_equal expression[:level], expression[:unary_level]
  end
  
  def test_not_expression_group
    @parser = Parser.new
    expressions = @parser.parse('Not (Test Eq 10 Or Test Eq 11)')
    assert !@parser.errors?, @parser.inspect
    expression = expressions.first
    assert_equal 10.to_s, expression[:value]
    assert_equal "Not", expression[:unary]
    assert_equal 0, expression[:unary_level]
  end

  def test_not_unary_expression_keeps_conjunction
    @parser = Parser.new
    expressions = @parser.parse('Test Lt 10 Or (Not Test Eq 11)')
    assert !@parser.errors?, @parser.inspect
    expression = expressions.last
    assert_equal 11.to_s, expression[:value]
    assert_equal "Not", expression[:unary]
    assert_equal "Or", expression[:conjunction]
    assert_equal expression[:level], expression[:unary_level]
    assert_equal 0, expression[:conjunction_level]
  end

  def test_not_not_expression
    @parser = Parser.new
    filter = "Not (Not ListPrice Eq 1) Not (Not BathsTotal Eq 2) And " +
             "(Not TotalRooms Eq 3) Or (HasPool Eq true)"

    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.inspect

    e1 = expressions.first
    e2 = expressions[1]
    e3 = expressions[2]
    e4 = expressions[3]

    assert_equal 1, e1[:level]
    assert_equal "Not", e1[:unary]
    assert_equal 1, e1[:unary_level]
    assert_equal "Not", e1[:conjunction]
    assert_equal 0, e1[:conjunction_level]
    assert_equal "Not", e2[:unary]
    assert_equal 1, e2[:unary_level]
    assert_equal "Not", e2[:conjunction]
    assert_equal 0, e2[:conjunction_level]
    assert_equal "Not", e3[:unary]
    assert_equal "And", e3[:conjunction]
    assert_nil e4[:unary]
    assert_equal "Or", e4[:conjunction]

    @parser = Parser.new
    filter = "Not (ListPrice Eq 1)"

    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.inspect

    e1 = expressions.first

    assert_equal "Not", e1[:unary]
    assert_equal 0, e1[:unary_level]
    assert_equal "And", e1[:conjunction]
    assert_equal 0, e1[:conjunction_level]

    filter = "(Not ListPrice Eq 1)"

    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.inspect

    e1 = expressions.first

    assert_equal "Not", e1[:unary]
    assert_equal 1, e1[:unary_level]
    assert_equal "And", e1[:conjunction]
    assert_equal 0, e1[:conjunction_level]

    filter = "Not (Not ListPrice Eq 1 Not BathsTotal Eq 2)"

    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.inspect

    e1 = expressions.first
    e2 = expressions[1]

    assert_equal "Not", e1[:unary]
    assert_equal 1, e1[:unary_level]
    assert_equal "Not", e1[:conjunction]
    assert_equal 0, e1[:conjunction_level]
    assert_nil e2[:unary]
    assert_nil e2[:unary_level]
    assert_equal 1, e2[:level]
    assert_equal "Not", e2[:conjunction]
    assert_equal 1, e2[:conjunction_level]

  end

  def test_expression_conditions_attribute
    conditions = [
      "1",
      "1,2",
      "1.0,2.1,3.1415",
      "'a '",
      "'A',' b'",
      "'A','B ',' c'",
      "radius('35.12 -68.33',1.0)",
      "days(-1),days(-7)",
      "2016-03-10",
      "2016-03-10T10:01:15.1-06:00"
    ]
    conditions.each do |condition|
      @parser = Parser.new
      expressions = @parser.parse("Test Eq #{condition}")
      assert !@parser.errors?, @parser.inspect
      expression = expressions.last
      assert_equal condition, expression[:condition]
    end
  end

  def test_bad_expressions_with_conditions_attribute
    conditions = [
      "BADSTRING",
      "radius('46.8 -96.8',-20.0)"
    ]
    conditions.each do |condition|
      @parser = Parser.new
      expressions = @parser.parse("Test Eq #{condition}")
      assert @parser.errors?, @parser.inspect
    end
  end

  def test_datetimes_as_ranges
    ["DatetimeField Bt 2013-07-26T10:22:15.422804,2013-07-26T10:22:15.422805",
     "DateTimeField Bt 2013-07-26T10:22:15,2013-07-26T10:22:16",
     "DateTimeField Bt 2013-07-26T10:22:15.422804-0300,2013-07-26T10:22:15.422805-0300",
     "DateTimeField Bt 2013-07-26T10:22:15+0400,2013-07-26T10:22:16+0400"].each do |filter|
      @parser = Parser.new
      expression = @parser.parse filter
      assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"
     end
  end
  
  def test_coercible_types
    @parser = Parser.new
    assert_equal :datetime, @parser.coercible_types(:date, :datetime)
    assert_equal :datetime, @parser.coercible_types(:datetime, :date)
    assert_equal :decimal, @parser.coercible_types(:decimal, :integer)
    assert_equal :decimal, @parser.coercible_types(:integer, :decimal)
    # That covers the gambit, anything else should be null
    assert_nil @parser.coercible_types(:integer, :date)
  end

end
