require 'test_helper'

class ParserTest < Test::Unit::TestCase
  include Sparkql

  def test_simple
    @parser = Parser.new
    parse 'Test Eq 10',10
    parse 'Test Eq 10.0',10.0
    parse 'Test Eq true',true
    parse "Test Eq 'false'","'false'"
  end
  
  def test_conjunction
    @parser = Parser.new
    expression = @parser.parse('Test Eq 10 And Test Ne 11')
    assert_equal 10, expression.first[:value]
    assert_equal 11, expression.last[:value]
    assert_equal 'And', expression.last[:conjunction]
    expression = @parser.parse('Test Eq 10 Or Test Ne 11')
    assert_equal 10, expression.first[:value]
    assert_equal 11, expression.last[:value]
    assert_equal 'Or', expression.last[:conjunction]
      
  end
  
  def test_tough_conjunction
    @parser = Parser.new
    expression = @parser.parse('Test Eq 10 Or Test Ne 11 And Test Ne 9')
    assert_equal 9, expression.last[:value]
    assert_equal 'And', expression.last[:conjunction]

  end

  def test_grouping
    @parser = Parser.new
    expression = @parser.parse('(Test Eq 10)').first
    assert_equal 10, expression[:value]
    expression = @parser.parse('(Test Eq 10 Or Test Ne 11)')
    assert_equal 10, expression.first[:value]
    assert_equal 11, expression.last[:value]
    assert_equal 'Or', expression.last[:conjunction]
    expression = @parser.parse('(Test Eq 10 Or (Test Ne 11))')
    assert_equal 10, expression.first[:value]
    assert_equal 11, expression.last[:value]
    assert_equal 'Or', expression.last[:conjunction]
  end

  def test_multiples
    @parser = Parser.new
    expression = @parser.parse('(Test Eq 10,11,12)').first
    assert_equal [10,11,12], expression[:value]
  end
    
  def parse(q,v)
    expressions = @parser.parse(q)
    puts "Expression #{expressions.inspect}"
    assert !@parser.errors?, "Unexpected error parsing #{q}"
    assert_equal v, expressions.first[:value], "Expression #{expressions.inspect}"
  end

  def test_derp
    @parser = Parser.new
    expression = @parser.parse('Test Eq DERP')
    assert @parser.errors?
    puts "ERRORS: #{@parser.errors.first}"
  end
  
end
