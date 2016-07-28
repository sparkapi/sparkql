require 'test_helper'
require 'support/boolean_or_bust_expression_resolver'

class EvaluatorTest < Test::Unit::TestCase
  include Sparkql

  def test_simple
    assert sample('Test Eq true')
    assert !sample('Test Eq false')
    assert sample("Test Eq 'Drop'")
  end

  def test_conjunction
    assert sample('Test Eq true And Test Eq true')
    assert !sample('Test Eq false And Test Eq true')
    assert !sample('Test Eq false And Test Eq false')
    # Ors
    assert sample("Test Eq true Or Test Eq true")
    assert sample("Test Eq true Or Test Eq false")
    assert sample("Test Eq false Or Test Eq true")
    assert !sample("Test Eq false Or Test Eq false")
  end

  def test_dropped_field_handling
    assert sample("Test Eq 'Drop' And Test Eq true")
    assert !sample("Test Eq 'Drop' And Test Eq false")
    assert !sample("Test Eq 'Drop' Or Test Eq false")
    assert sample("Test Eq 'Drop' Or Test Eq true")
    assert sample("Test Eq false And Test Eq 'Drop' Or Test Eq true")
    assert sample("Test Eq false Or (Test Eq 'Drop' And Test Eq true)")
  end

  def test_nesting
    assert sample("Test Eq true Or (Test Eq true) And Test Eq false And (Test Eq true)")
    assert sample("Test Eq true Or ((Test Eq false) And Test Eq false) And (Test Eq false)")
    assert sample("(Test Eq false Or Test Eq true) Or (Test Eq false Or Test Eq false)")
    assert sample("(Test Eq true And Test Eq true) Or (Test Eq false)")
    assert sample("(Test Eq true And Test Eq true) Or (Test Eq false And Test Eq true)")
    assert !sample("(Test Eq false And Test Eq true) Or (Test Eq false)")
    assert sample("Test Eq true And ((Test Eq true And Test Eq false) Or Test Eq true)")
    assert !sample("Test Eq true And ((Test Eq true And Test Eq false) Or Test Eq false) And Test Eq true")
    assert !sample("Test Eq true And ((Test Eq true And Test Eq false) Or Test Eq false) Or Test Eq false")
    assert sample("Test Eq true And ((Test Eq true And Test Eq false) Or Test Eq false) Or Test Eq true")
  end

  def test_nots
    assert !sample("Not Test Eq true")
    assert sample("Not Test Eq false")
    assert !sample("Not (Test Eq true)")
    assert sample("Not (Test Eq false)")
    assert sample("Test Eq true Not Test Eq false")
    assert !sample("Test Eq true Not Test Eq true")
    assert sample("Test Eq true Not (Test Eq false Or Test Eq false)")
    assert sample("Test Eq true Not (Test Eq false And Test Eq false)")
    assert !sample("Test Eq true Not (Test Eq false Or Test Eq true)")
    assert !sample("Test Eq true Not (Test Eq true Or Test Eq false)")
    assert !sample("Test Eq true Not (Not Test Eq false)")
    assert sample("Not (Not Test Eq true)")
    assert sample("Not (Not(Not Test Eq true))")
  end

  def test_optimizations
    assert sample("Test Eq true Or Test Eq false And Test Eq false")
    assert_equal 1, @evaluator.processed_count
    assert sample("Test Eq false Or Test Eq true And Test Eq true")
    assert_equal 3, @evaluator.processed_count
    assert sample("(Test Eq true Or Test Eq false) And Test Eq true")
    assert_equal 2, @evaluator.processed_count
    assert sample("(Test Eq false Or Test Eq true) And Test Eq true")
    assert_equal 3, @evaluator.processed_count
  end

  # Here's some examples from prospector's tests that have been simplified a bit.
  def test_advanced
    assert !sample("MlsStatus Eq false And PropertyType Eq true And (City Eq true Or City Eq false)")
  end

  def sample filter
    @parser = Parser.new
    @expressions = @parser.parse(filter)
    @evaluator = Evaluator.new(BooleanOrBustExpressionResolver.new())
    @evaluator.evaluate(@expressions)
  end
end
