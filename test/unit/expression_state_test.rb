require 'test_helper'

class ExpressionStateTest < Test::Unit::TestCase
  include Sparkql

  def setup
    @subject = ExpressionState.new
    @parser = Parser.new
  end

  def test_needs_join
    filter = '"General Property Description"."Taxes" Lt 500.0'
    process(filter)
    assert @subject.needs_join?
  end

  def test_or
    filter = '"General Property Description"."Taxes" Lt 500.0 Or "General Property Description"."Taxes" Gt 400.0'
    process(filter)
    assert !@subject.needs_join?, "#{@subject.inspect} Expressions:#{@expressions.inspect}"
  end

  def test_not
    filter = '"General Property Description"."Taxes" Lt 500.0 Not "General Property Description"."Taxes2" Eq 1.0'
    process(filter)
    assert @subject.needs_join?
  end

  def test_and
    filter = '"General Property Description"."Taxes" Lt 500.0 And "General Property Description"."Taxes2" Eq 1.0'
    process(filter)
    assert @subject.needs_join?
  end

  def test_and_or
    filter = '"General Property Description"."Taxes" Lt 500.0 And "General Property Description"."Taxes2" ' \
             'Eq 1.0 Or "General Property Description"."Taxes" Gt 400.0'
    process(filter)
    assert !@subject.needs_join?
  end

  def test_or_and
    filter = '"General Property Description"."Taxes" Lt 500.0 Or "General Property Description"."Taxes" ' \
             'Gt 400.0 And "General Property Description"."Taxes2" Eq 1.0'
    process(filter)
    assert @subject.needs_join?
  end

  def test_or_with_standard_field
    filter = 'Test Eq 0.0 Or "General Property Description"."Taxes" Lt 500.0'
    process(filter)
    assert @subject.needs_join?
  end

  # Nesting
  def test_nested_or
    parse '"General Property Description"."Taxes" Lt 5.0 Or ("General Property Description"."Taxes" Gt 4.0)'
    @expressions.each do |ex|
      @subject.push(ex)
      assert @subject.needs_join?, "#{@subject.inspect} Expression:#{ex.inspect}"
    end
  end

  def test_nested_ors
    parse '"Tax"."Taxes" Lt 5.0 Or ("Tax"."Taxes" Gt 4.0 Or "Tax"."Taxes" Gt 2.0)'
    @subject.push(@expressions[0])
    assert @subject.needs_join?
    @subject.push(@expressions[1])
    assert @subject.needs_join?
    @subject.push(@expressions[2])
    assert !@subject.needs_join?
  end

  # Nesting
  def test_nested_and
    parse '"Tax"."Taxes" Lt 5.0 Or ("Tax"."Taxes" Gt 4.0 And "Tax"."Taxes" Gt 2.0)'
    @expressions.each do |ex|
      @subject.push(ex)
      assert @subject.needs_join?, "#{@subject.inspect} Expression:#{ex.inspect}"
    end
  end

  def parse(filter)
    @expressions = @parser.parse(filter)
  end

  def process(filter)
    @expressions = @parser.parse(filter)
    @expressions.each do |ex|
      @subject.push(ex) if ex[:custom_field] == true
    end
    @expressions
  end
end
