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
    expression = @parser.parse('Test Eq 10 Not Test Ne 11')
    assert_equal 10.to_s, expression.first[:value]
    assert_equal 11.to_s, expression.last[:value]
    assert_equal 'Not', expression.last[:conjunction]
  end
  
  def test_tough_conjunction
    @parser = Parser.new
    expression = @parser.parse('Test Eq 10 Or Test Ne 11 And Test Ne 9')
    assert_equal 9.to_s, expression.last[:value]
    assert_equal 'And', expression.last[:conjunction]
    assert_equal '9', expression.last[:condition]
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
    assert_equal '10,11,12', expression[:condition]
  end
    
  def parse(q,v)
    expressions = @parser.parse(q)
    assert !@parser.errors?, "Unexpected error parsing #{q} #{@parser.errors.inspect}"
    assert_equal v, expressions.first[:value], "Expression #{expressions.inspect}"
    assert !expressions.first[:custom_field], "Unexepected custom field #{expressions.inspect}"
  end

  def test_invalid_syntax
    @parser = Parser.new
    expression = @parser.parse('Test Eq DERP')
    assert @parser.errors?, "Should be nil: #{expression}"
  end
  
  def test_nesting
    assert_nesting(
      "City Eq 'Fargo' Or (BathsFull Eq 1 Or BathsFull Eq 2) Or City Eq 'Moorhead' Or City Eq 'Dilworth'",
      [0,1,1,0,0]
    )
  end
  
  def test_nesting_and_functions
    # Nesting with a function thrown in. Yes, this was a problem.
    assert_nesting(
      "City Eq 'Fargo' Or (BathsFull Eq 1 And Location Eq rectangle('35.12 -68.33, 35.13 -68.32')) Or Location Eq radius('35.12 -68.33',10.0) Or City Eq 'Dilworth'",
      [0,1,1,0,0]
    )
  end

  def test_multilevel_nesting
    assert_nesting(
      "(City Eq 'Fargo' And (BathsFull Eq 1 Or BathsFull Eq 2)) Or City Eq 'Moorhead' Or City Eq 'Dilworth'",
      [1,2,2,0,0]
    )
    
    # API-629
    assert_nesting(
      "((MlsStatus Eq 'A') Or (MlsStatus Eq 'D' And CloseDate Ge 2011-05-17)) And ListPrice Ge 150000.0 And PropertyType Eq 'A'",
      [2,2,2,0,0],
      [2,3,3,0,0]
    )
    assert_nesting(
      "ListPrice Ge 150000.0 And PropertyType Eq 'A' And ((MlsStatus Eq 'A') Or (MlsStatus Eq 'D' And CloseDate Ge 2011-05-17))",
      [0,0,2,2,2],
      [0,0,2,3,3]
    )
  end
  
  # verify each expression in the query is at the right nesting level and group
  def assert_nesting(sparkql, levels=[], block_groups=nil)
    block_groups = levels.clone if block_groups.nil?
    parser = Parser.new
    expressions = parser.parse(sparkql)
    assert !parser.errors?, "Unexpected error parsing #{sparkql}: #{parser.errors.inspect}"
    count = 0
    expressions.each do |ex|
      assert_equal levels[count],  ex[:level], "Nesting level wrong for #{ex.inspect}"
      assert_equal(block_groups[count],  ex[:block_group], "Nesting block group wrong for #{ex.inspect}")
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

  def test_function_months
    dt = DateTime.new(2014, 1, 5, 0, 0, 0, 0)
    DateTime.expects(:now).returns(dt)
    @parser = Parser.new
    expressions = @parser.parse "ExpirationDate Gt months(-3)"
    assert !@parser.errors?, "errors :( #{@parser.errors.inspect}"
    assert_equal "2013-10-05", expressions.first[:value]
    assert_equal 'months(-3)', expressions.first[:condition]
  end

  def test_function_years
    dt = DateTime.new(2014, 1, 5, 0, 0, 0, 0)
    DateTime.expects(:now).returns(dt)
    @parser = Parser.new
    expressions = @parser.parse "SoldDate Lt years(2)"
    assert !@parser.errors?, "errors :( #{@parser.errors.inspect}"
    assert_equal "2016-01-05", expressions.first[:value]
    assert_equal 'years(2)', expressions.first[:condition]
  end

  def test_function_days
    d = Date.today
    dt = DateTime.new(d.year, d.month,d.day, 0,0,0, DateTime.now.offset)
    start = Time.parse(dt.to_s)
    filter = "OriginalEntryTimestamp Ge days(-7)"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal 'days(-7)', expressions.first[:condition]

    test_time = Time.parse(expressions.first[:value])
    
    assert (-605000 < test_time - start && -604000 > test_time - start), "Time range off by more than five seconds #{test_time - start} '#{test_time} - #{start}'"
  end

  def test_function_now
    start = Time.now
    filter = "City Eq now()"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal 'now()', expressions.first[:condition]
    test_time = Time.parse(expressions.first[:value])
    assert 5 > test_time - start, "Time range off by more than five seconds #{test_time - start}"
    assert -5 < test_time - start, "Time range off by more than five seconds #{test_time - start}"
  end

  test "function data preserved in expression" do
    filter = "OriginalEntryTimestamp Ge days(-7)"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert_equal 'days', expressions.first[:function_name]
    assert_equal 'days(-7)', expressions.first[:condition]
    assert_equal([-7], expressions.first[:function_parameters])
  end
  
  test "function rangeable " do
    filter = "OriginalEntryTimestamp Bt days(-7),days(-1)"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert_equal(2, expressions.first[:value].size)
    assert_equal 'days(-7),days(-1)', expressions.first[:condition]
  end

  test "mixed rangeable " do
    filter = "OriginalEntryTimestamp Bt days(-7),2013-07-26"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert_equal(2, expressions.first[:value].size)
    assert_equal("2013-07-26", expressions.first[:value].last)
    assert_equal 'days(-7),2013-07-26', expressions.first[:condition]
  end

  test "function list" do
    filter = "OriginalEntryTimestamp Eq days(-1),days(-7),days(-30)"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert_equal(3, expressions.first[:value].size)
    assert_equal 'days(-1),days(-7),days(-30)', expressions.first[:condition]
  end

  test "mixed list" do
    # TODO This is an unrealistic example. We need number functions or support 
    # for dates in lists
    filter = "OriginalEntryTimestamp Eq 2014,days(-7)"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert_equal(2, expressions.first[:value].size)
    assert_equal("2014", expressions.first[:value].first)
    assert_equal '2014,days(-7)', expressions.first[:condition]
  end
  
  test "Location Eq polygon()" do
    filter = "Location Eq polygon('35.12 -68.33, 35.13 -68.33, 35.13 -68.32, 35.12 -68.32')"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal "polygon('35.12 -68.33, 35.13 -68.33, 35.13 -68.32, 35.12 -68.32')", expressions.first[:condition]
    assert_equal :shape, expressions.first[:type]
    assert_equal [[-68.33, 35.12], [-68.33, 35.13], [-68.32,35.13], [-68.32,35.12],[-68.33, 35.12]], expressions.first[:value].to_coordinates.first, "#{expressions.first[:value].inspect} "
  end

  test "Location Eq rectangle()" do
    filter = "Location Eq rectangle('35.12 -68.33, 35.13 -68.32')"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal :shape, expressions.first[:type]
    assert_equal [[-68.33,35.12], [-68.32,35.12], [-68.32,35.13], [-68.33,35.13], [-68.33,35.12]], expressions.first[:value].to_coordinates.first, "#{expressions.first[:value].inspect} "
  end

  test "Location Eq radius()" do
    # This exposed a funny nesting limit problem FUN!
    filter = "Location Eq radius('35.12 -68.33',1.0)"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal :shape, expressions.first[:type]
    assert_equal [-68.33, 35.12], expressions.first[:value].center.to_coordinates, "#{expressions.first[:value].inspect} "
    assert_equal 1.0, expressions.first[:value].radius, "#{expressions.first[:value].inspect} "
  end

  test "Location eq radius() error on invalid syntax" do
    filter = "Location Eq radius('35.12,-68.33',1.0)"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert @parser.errors?, "Parser error expected due to comma between radius points"
  end
  
  test "Location ALL TOGETHER NOW" do
    filter = "Location Eq radius('35.12 -68.33',1.0) And Location Eq rectangle('35.12 -68.33, 35.13 -68.32') And Location Eq polygon('35.12 -68.33, 35.13 -68.33, 35.13 -68.32, 35.12 -68.32')"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal [:shape,:shape,:shape], expressions.map{|e| e[:type]}
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
      '"Garage Type"."1" Eq true',
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

  def test_case_insensitve_ops_and_conjunctions
    @parser = Parser.new
    parse 'Test EQ 10',10.to_s
    parse 'Test eq 10.0',10.0.to_s
    parse 'Test eQ true',true.to_s
    parse 'Test EQ 10 AND Test NE 11', 10.to_s
    parse 'Test eq 10 or Test ne 11', 10.to_s
    parse 'Test eq 10 NOT Test ne 11', 10.to_s
  end
  
  def test_null
    @parser = Parser.new
    parse 'Test Eq NULL', "NULL"
    parse 'Test Eq NULL Or Test Ne 11', "NULL"
  end

  def test_invalid_operators
    (Sparkql::Token::OPERATORS - Sparkql::Token::EQUALITY_OPERATORS).each do |o|
      ["NULL", "true", "'My String'"].each do |v|
        parser_errors("Test #{o} #{v}")
      end
    end
  end
  
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

  def test_expression_conditions_attribute
    conditions = [
      "1",
      "1,2",
      "1.0,2.1,3.1415",
      "'a '",
      "'A',' b'",
      "'A','B ',' c'",
      "radius('35.12 -68.33',1.0)",
      "days(-1),days(-7)"
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


  def parser_errors(filter)  
    @parser = Parser.new
    expression = @parser.parse(filter)
    assert @parser.errors?, "Should find errors for '#{filter}': #{expression}"
  end
    
end
