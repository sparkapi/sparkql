require 'test_helper'

class ParserTest < Test::Unit::TestCase
  include Sparkql

  def test_simple
    @parser = Parser.new
    parse 'Test Eq 10',10.to_s
    parse 'Test Eq 10.0',10.0.to_s
    parse 'Test Eq true',true.to_s
    parse "Test Eq 'false'","'false'"
  end
  
  def test_conjunction
    @parser = Parser.new
    expression = @parser.parse('Test Eq 10 And Test Ne 11')
    assert_equal 10.to_s, expression.first[:value]
    assert_equal 11.to_s, expression.last[:value]
    assert_equal 'And', expression.last[:conjunction]
    expression = @parser.parse('Test Eq 10 Or Test Ne 11')
    assert_equal 10.to_s, expression.first[:value]
    assert_equal 11.to_s, expression.last[:value]
    assert_equal 'Or', expression.last[:conjunction]
  end
  
  def test_tough_conjunction
    @parser = Parser.new
    expression = @parser.parse('Test Eq 10 Or Test Ne 11 And Test Ne 9')
    assert_equal 9.to_s, expression.last[:value]
    assert_equal 'And', expression.last[:conjunction]
  end

  def test_grouping
    @parser = Parser.new
    expression = @parser.parse('(Test Eq 10)').first
    assert_equal 10.to_s, expression[:value]
    expression = @parser.parse('(Test Eq 10 Or Test Ne 11)')
    assert_equal 10.to_s, expression.first[:value]
    assert_equal 11.to_s, expression.last[:value]
    assert_equal 'Or', expression.last[:conjunction]
    expression = @parser.parse('(Test Eq 10 Or (Test Ne 11))')
    assert_equal 10.to_s, expression.first[:value]
    assert_equal 11.to_s, expression.last[:value]
    assert_equal 'Or', expression.last[:conjunction]
  end

  def test_multiples
    @parser = Parser.new
    expression = @parser.parse('(Test Eq 10,11,12)').first
    assert_equal [10.to_s,11.to_s,12.to_s], expression[:value]
  end
    
  def parse(q,v)
    expressions = @parser.parse(q)
    assert !@parser.errors?, "Unexpected error parsing #{q}"
    assert_equal v, expressions.first[:value], "Expression #{expressions.inspect}"
    assert !expressions.first[:custom_field], "Unexepected custom field #{expressions.inspect}"
  end

  def test_invalid_syntax
    @parser = Parser.new
    expression = @parser.parse('Test Eq DERP')
    assert @parser.errors?, "Should be nil: #{expression}"
  end
  
  def test_nesting
    filter = "City Eq 'Fargo' Or (BathsFull Eq 1 Or BathsFull Eq 2) Or City Eq 'Moorhead' Or City Eq 'Dilworth'"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "Unexpected error parsing #{filter}"
    levels = [0,1,1,0,0]
    count = 0
    expressions.each do |ex|
      assert_equal levels[count],  ex[:level], "Nesting level wrong for #{ex.inspect}"
      assert_equal levels[count],  ex[:block_group], "Nesting block group wrong for #{ex.inspect}"
      count +=1
    end
  end

  def test_multilevel_nesting
    filter = "(City Eq 'Fargo' And (BathsFull Eq 1 Or BathsFull Eq 2)) Or City Eq 'Moorhead' Or City Eq 'Dilworth'"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "Unexpected error parsing #{filter}: #{@parser.errors.inspect}"
    levels = [1,2,2,0,0]
    count = 0
    expressions.each do |ex|
      assert_equal levels[count],  ex[:level], "Nesting level wrong for #{ex.inspect}"
      assert_equal levels[count],  ex[:block_group], "Nesting block group wrong for #{ex.inspect}"
      count +=1
    end
  end
   
  def test_bad_queries
    filter = "City IsLikeA 'Town'"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert @parser.errors?, "Should be nil: #{expressions}"
    assert @parser.fatal_errors?, "Should be nil: #{@parser.errors.inspect}"
  end

  def test_function_days
    start = Time.now
    filter = "OriginalEntryTimestamp Ge days(-7)"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    test_time = Time.parse(expressions.first[:value])
    assert -605000 < test_time - start, "Time range off by more than five seconds #{test_time - start}"
    assert -604000 > test_time - start, "Time range off by more than five seconds #{test_time - start}"
  end

  def test_function_now
    start = Time.now
    filter = "City Eq now()"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    test_time = Time.parse(expressions.first[:value])
    assert 5 > test_time - start, "Time range off by more than five seconds #{test_time - start}"
    assert -5 < test_time - start, "Time range off by more than five seconds #{test_time - start}"
  end
  
  def test_for_reserved_words_first_literals_second
    ["OrOrOr Eq true", "Equador Eq true", "Oregon Ge 10"].each do |filter|
      @parser = Parser.new
      expressions = @parser.parse(filter)
      assert !@parser.errors?, "Filter '#{filter}' errors: #{@parser.errors.inspect}"
    end
  end
  
  def test_custom_fields
    filter = '"General Property Description"."Taxes" Lt 500.0'
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal '"General Property Description"."Taxes"', expressions.first[:field], "Custom field expression #{expressions.inspect}"
    assert expressions.first[:custom_field], "Custom field expression #{expressions.inspect}"
    assert_equal '500.0', expressions.first[:value], "Custom field expression #{expressions.inspect}"
  end
  
  def test_valid_custom_field_filters
    ['"General Property Description"."Taxes$" Lt 500.0',
      '"General Property Desc\'"."Taxes" Lt 500.0',
      '"General Property Description"."Taxes" Lt 500.0',
      '"General \'Property\' Description"."Taxes" Lt 500.0',
      '"General Property Description"."Taxes #" Lt 500.0',
      '"General$Description"."Taxes" Lt 500.0',
      '" a "." b " Lt 500.0'
    ].each do |filter|
      @parser = Parser.new
      expressions = @parser.parse(filter)
      assert !@parser.errors?, "errors '#{filter}'\n#{@parser.errors.inspect}"
    end
  end
  
  def test_invalid_custom_field_filters
    ['"$General Property Description"."Taxes" Lt 500.0',
      '"General Property Description"."$Taxes" Lt 500.0',
      '"General Property Description"."Tax.es" Lt 500.0',
      '"General Property Description".".Taxes" Lt 500.0',
      '"General Property Description".".Taxes"."SUB" Lt 500.0',
      '"General.Description"."Taxes" Lt 500.0',
      '""."" Lt 500.0'
    ].each do |filter|
      @parser = Parser.new
      expressions = @parser.parse(filter)
      assert @parser.errors?, "No errors? '#{filter}'\n#{@parser.inspect}"
    end
  end

end
