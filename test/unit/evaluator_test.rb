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

  # One passing or expression in the set should always affirm a match this tests
  # every permutation of one passing expression
  def test_ors_stay_good
    5.times do |i|
      expressions = []
      5.times do |j|
        expressions << "Test Eq #{i == j}"
      end
      filter = expressions.join(" Or ")
      assert sample(filter), "Filter: #{filter}"
    end
  end

  # One failing AND expression in a set should always fail. Here we ensure every
  # permutation of one failing
  def test_ands_stay_bad
    5.times do |i|
      expressions = []
      5.times do |j|
        expressions << "Test Eq #{i != j}"
      end
      filter = expressions.join(" And ")
      assert !sample(filter), "Filter: #{filter}"
    end
  end

  # One failing Not expression in a set should always fail. Here we ensure every
  # permutation of one failing
  def test_nots_stay_bad
    5.times do |i|
      expressions = []
      5.times do |j|
        expressions << "Test Eq #{i == j}"
      end
      # Add the unary not to the front!
      filter = "Not #{expressions.join(' Not ')}"
      assert !sample(filter), "Filter: #{filter}"
    end
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
    assert !sample("Test Eq false And Test Eq true Not Test Eq false")
    assert !sample("Test Eq true Not (Test Eq false Or Test Eq false) And (Test Eq false Or Test Eq false)")
  end

  def test_examples
    # This one is based on a real life example that had problems.
    #
    # CurrentPrice Bt 130000.00,180000.00 And PropertySubType Eq 'Single Family Residence' And
    # SchoolDistrict Eq 'Byron Center','Grandville','Jenison' And MlsStatus Eq 'Active' And
    # BathsTotal Bt 1.50,9999.00 And BedsTotal Bt 3,99 And PropertyType Eq 'A'
    # Not "Garage"."Garage2" Eq 'No' And "Pool"."OutdoorAbove" Eq true
    # And "Pool"."OutdoorInground" Eq true Not "Substructure"."Michigan Basement" Eq true

    assert !sample("Test Eq false And Test Eq true And " \
      "Test Eq false And Test Eq true And " \
      "Test Eq true And Test Eq true And Test Eq true " \
      "Not Test Eq false And Test Eq false " \
      "And Test Eq false Not Test Eq false")
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

  def sample(filter)
    @parser = Parser.new
    @expressions = @parser.parse(filter)
    @evaluator = Evaluator.new(BooleanOrBustExpressionResolver.new)
    @evaluator.evaluate(@expressions)
  end
end
