require 'test_helper'

class ParserTest < Test::Unit::TestCase
  include Sparkql

  def test_simple
    @parser = Parser.new
    parse 'Test Eq 10',10
    parse 'Test Eq 10.0',10.0
    parse 'Test Eq true',true
    parse "Test Eq 'false'",'false'
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

  def test_grouping
    @parser = Parser.new
    expression = @parser.parse('(Test Eq 10)')
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
  
  def parse(q,v)
    expression = @parser.parse(q)
    puts "Expression #{expression.inspect}"
    assert_equal v, expression[:value], "Expression #{expression.inspect}"
  end
  
end
