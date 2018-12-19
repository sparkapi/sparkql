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
    start = Time.utc(d.year,d.month,d.day,0,0,0)
    filter = "OriginalEntryTimestamp Ge days(-7)"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal 'days(-7)', expressions.first[:condition]

    vals = expressions.first[:value].split('-')

    test_time = Time.utc(vals[0].to_i, vals[1].to_i, vals[2].to_i)
    
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

  def test_function_range
    filter = "MapCoordinates Eq range('M01','M04')"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal "range('M01','M04')", expressions.first[:condition]
    assert_equal 'M01', expressions.first[:value].first
    assert_equal 'M04', expressions.first[:value][1]
  end

  test 'indexof with field' do
    filter = "indexof(City, '4131800000000') Eq 13"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal 'City', expression[:field]
    assert_equal '13', expression[:value]
    assert_equal '4131800000000', expression[:args].last

    assert_equal 'indexof', expression[:field_manipulations][:function_name]
    assert_equal :function, expression[:field_manipulations][:type]
    assert_equal :integer, expression[:field_manipulations][:return_type]
    assert_equal ['City', '4131800000000'], expression[:field_manipulations][:args].map {|v| v[:value]}
  end

  test 'add' do
    @parser = Parser.new
    filter = "Baths Add 2 Eq 1"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    field_manipulations = expressions.first[:field_manipulations]
    assert_equal :arithmetic, field_manipulations[:type]
    assert_equal 'Add', field_manipulations[:op]
  end

  test 'Sub' do
    @parser = Parser.new
    filter = "Baths Sub 2 Eq 1"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    field_manipulations = expressions.first[:field_manipulations]
    assert_equal :arithmetic, field_manipulations[:type]
    assert_equal 'Sub', field_manipulations[:op]
  end

  test 'Mul' do
    @parser = Parser.new
    filter = "Baths Mul 2 Eq 1"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    field_manipulations = expressions.first[:field_manipulations]
    assert_equal :arithmetic, field_manipulations[:type]
    assert_equal 'Mul', field_manipulations[:op]
  end

  test 'Div' do
    @parser = Parser.new
    filter = "Baths Div 2 Eq 1"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    field_manipulations = expressions.first[:field_manipulations]
    assert_equal :arithmetic, field_manipulations[:type]
    assert_equal 'Div', field_manipulations[:op]
  end

  test 'Mod' do
    @parser = Parser.new
    filter = "Baths Mod 2 Eq 1"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    field_manipulations = expressions.first[:field_manipulations]
    assert_equal :arithmetic, field_manipulations[:type]
    assert_equal 'Mod', field_manipulations[:op]
  end

  test 'Mod returns decimal precision' do
    @parser = Parser.new
    filter = "Baths Eq 32.7 Mod 20.7"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect
    assert_equal '12.0', expressions.first[:value]
  end

  test 'Adding returns decimal precision' do
    @parser = Parser.new
    filter = "Baths Eq 0.1 Add 0.2"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect
    assert_equal '0.3', expressions.first[:value]
  end

  test 'Subtracting returns decimal precision' do
    @parser = Parser.new
    filter = "Baths Eq 0.3 Sub 0.1"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect
    assert_equal '0.2', expressions.first[:value]
  end

  test 'Division returns decimal precision' do
    @parser = Parser.new
    filter = "Baths Eq 0.6 Div 0.2"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect
    assert_equal '3.0', expressions.first[:value]
  end

  test 'Arithmetic rounds to 20 decimal places' do
    @parser = Parser.new
    filter = "Baths Eq 7 Div 10.1"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect
    assert_equal '0.69306930693069306931', expressions.first[:value]
  end

  test 'Multiplication returns decimal precision' do
    @parser = Parser.new
    filter = "Baths Eq 7 Mul 0.1"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect
    assert_equal '0.7', expressions.first[:value]
  end

  test 'arithmetic with field function' do
    @parser = Parser.new
    filter = "floor(Baths) Add 2 Eq 1"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    field_manipulations = expressions.first[:field_manipulations]
    assert_equal :arithmetic, field_manipulations[:type]
    assert_equal 'Add', field_manipulations[:op]
    assert_equal :function, field_manipulations[:lhs][:type]
  end

  test 'Bad type function with arithmetic' do
    @parser = Parser.new
    filter = "trim(Baths) Add 2 Eq 1"
    @parser.parse(filter)
    assert @parser.errors?
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
    filter = "OriginalEntryTimestamp Eq 2014,days(-7)"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert_equal(2, expressions.first[:value].size)
    assert_equal("2014", expressions.first[:value].first)
    assert_equal '2014,days(-7)', expressions.first[:condition]
  end

  def test_errors_on_left_hand_field_function
    parser_errors("Field Eq ceiling(Field)")
  end

  def test_function_date
    # Run using a static value, we just resolve the type
    filter = "OnMarketDate Eq date(2013-07-26T10:22:15.111-0100)"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal 'date(2013-07-26T10:22:15.111-0100)', expressions.first[:condition]
    assert_equal '2013-07-26', expressions.first[:value]
    assert_equal :date, expressions.first[:type]
    # And the grand finale: run on both sides
    filter = "date(OriginalEntryTimestamp) Eq date(2013-07-26T10:22:15.111-0100)"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal 'date(2013-07-26T10:22:15.111-0100)', expression[:condition]
    assert_equal '2013-07-26', expression[:value]
    assert_equal :date, expression[:type]
    # annnd the field function stuff
    assert_equal "OriginalEntryTimestamp", expression[:field]
    assert_equal :date, expression[:field_function_type]
    assert_equal "date", expression[:field_function]
  end

  test "regex function parses without second param" do
    filter = "ParcelNumber Eq regex('^[0-9]{3}-[0-9]{2}-[0-9]{3}$')"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert_equal '', expression[:function_parameters][1]
    assert_equal '^[0-9]{3}-[0-9]{2}-[0-9]{3}$', expression[:function_parameters][0]
  end

  test "regex function parses with case-insensitive flag" do
    filter = "ParcelNumber Eq regex('^[0-9]{3}-[0-9]{2}-[0-9]{3}$', 'i')"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert_equal 'i', expression[:function_parameters][1]
    assert_equal '^[0-9]{3}-[0-9]{2}-[0-9]{3}$', expression[:function_parameters][0]
  end

  test "invalid regex" do
    filter = "ParcelNumber Eq regex('[1234', '')"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert @parser.errors?, "Parser error expected due to invalid regex"
  end

  test "allow timezone offsets" do
    values = [
      "2013-07-26",
      "10:22",
      "10:22:15.1111",
      "10:22:15",
      "2013-07-26T10:22",
      "2013-07-26T10:22Z",
      "2013-07-26T10:22+01:00",
      "2013-07-26T10:22:15+01:00",
      "2013-07-26T10:22:15.1-01:00",
      "2013-07-26T10:22:15.11+0100",
      "2013-07-26T10:22:15.111-0100",
      "2013-07-26T10:22:15.1111Z",
      "2013-07-26T10:22:15.11111+01:00",
      "2013-07-26T10:22:15.111111+01:00"
    ]
    values.each do |value|
      filter = "DatetimeField Eq #{value}"
      @parser = Parser.new
      expressions = @parser.parse(filter)
      assert !@parser.errors?, "errors #{@parser.errors.inspect}"
      assert_not_nil expressions, "#{value} failed"
      assert_equal expressions.first[:value], value, "#{value} failed"
    end
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

  test "Location Eq linestring()" do
    filter = "Location Eq linestring('35.12 -68.33, 35.13 -68.33')"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal "linestring('35.12 -68.33, 35.13 -68.33')", expressions.first[:condition]
    assert_equal :shape, expressions.first[:type]
    assert_equal [[-68.33, 35.12], [-68.33, 35.13]], expressions.first[:value].to_coordinates, "#{expressions.first[:value].inspect} "

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

  test "Location Eq radius() accepts integer" do
    filter = "Location Eq radius('35.12 -68.33',1)"
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
    filter = "Location Eq linestring('35.12 -68.33, 35.13 -68.33') And Location Eq radius('35.12 -68.33',1.0) And Location Eq rectangle('35.12 -68.33, 35.13 -68.32') And Location Eq polygon('35.12 -68.33, 35.13 -68.33, 35.13 -68.32, 35.12 -68.32')"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal [:shape,:shape,:shape,:shape], expressions.map{|e| e[:type]}
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

  def test_literal_group
    filter = "ListPrice Gt (5)"
    @parser = Parser.new
    @parser.parse(filter)
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"
  end

  def test_integer_negation
    filter = "ListPrice Gt -(5)"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal :integer, expression[:type]
    assert_equal '-5', expression[:value]
  end

  def test_decimal_negation
    filter = "ListPrice Gt -(5.1)"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    expression = expressions.first
    assert_equal :decimal, expression[:type]
    assert_equal '-5.1', expression[:value]
  end

  def test_nested_negation
    filter = "ListPrice Gt -(-5)"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal :integer, expression[:type]
    assert_equal '5', expression[:value]

    filter = "ListPrice Gt --5"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal :integer, expression[:type]
    assert_equal '5', expression[:value]
  end

  def test_string_negation_does_not_parse
    parser_errors("Field Eq -'Stringval'")
  end


  test "field negation" do
    @parser = Parser.new
    expressions = @parser.parse('-Test Eq 10')
    assert !@parser.errors?

    assert_equal 'Negation', expressions.first[:field_manipulations][:op]
    assert_equal 'Test', expressions.first[:field]
  end

  def test_substring
    filter = "Name Eq substring('Andy', 1)"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"
    assert_equal 'ndy', expression[:value]
  end

  def test_round_with_literal
    filter = "ListPrice Eq round(0.5)"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal :integer, expression[:type]
    assert_equal "1", expression[:value]

    filter = "ListPrice Eq round(-0.5)"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal :integer, expression[:type]
    assert_equal "-1", expression[:value]
  end

  def test_round_with_field
    filter = "round(ListPrice) Eq 1"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal 'round', expression[:field_function]
    assert_equal(["ListPrice"], expression[:args])

    assert_equal 'round', expression[:field_manipulations][:function_name]
    assert_equal :function, expression[:field_manipulations][:type]
    assert_equal ['ListPrice'], expression[:field_manipulations][:args].map {|v| v[:value]}
  end

  def test_ceiling_with_literal
    filter = "ListPrice Eq ceiling(0.5)"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal :integer, expression[:type]
    assert_equal "1", expression[:value]

    filter = "ListPrice Eq ceiling(-0.5)"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal :integer, expression[:type]
    assert_equal "0", expression[:value]
  end

  def test_ceiling_with_field
    filter = "ceiling(ListPrice) Eq 4"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal 'ceiling', expression[:field_function]
    assert_equal(["ListPrice"], expression[:args])
  end

  def test_floor_with_literal
    filter = "ListPrice Eq floor(0.5)"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal :integer, expression[:type]
    assert_equal "0", expression[:value]

    filter = "ListPrice Eq floor(-0.5)"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal :integer, expression[:type]
    assert_equal "-1", expression[:value]
  end

  def test_floor_with_field
    filter = "floor(ListPrice) Eq 1"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal 'floor', expression[:field_function]
    assert_equal(["ListPrice"], expression[:args])

    assert_equal 'floor', expression[:field_manipulations][:function_name]
    assert_equal :function, expression[:field_manipulations][:type]
    assert_equal ['ListPrice'], expression[:field_manipulations][:args].map {|v| v[:value]}
  end

  def test_concat_with_field
    filter = "concat(City, 'b') Eq 'Fargob'"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal :character, expression[:type]
    assert_equal 'concat', expression[:field_function]
    assert_equal(["City", 'b'], expression[:args])
    assert_equal("City", expression[:field])

    assert_equal 'concat', expression[:field_manipulations][:function_name]
    assert_equal :function, expression[:field_manipulations][:type]
    assert_equal ['City', 'b'], expression[:field_manipulations][:args].map {|v| v[:value]}
  end

  def test_concat_with_literal
    filter = "City Eq concat('a', 'b')"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal 'concat', expression[:function_name]
    assert_equal :character, expression[:type]
    assert_equal "'ab'", expression[:value]
    assert_equal ["a", "b"], expression[:function_parameters]
  end

  def test_cast_with_field
    filter = "cast(ListPrice, 'character') Eq '100000'"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"

    assert_equal 'cast', expression[:field_function]
    assert_equal "'100000'", expression[:condition]
    assert_equal(:character, expression[:field_function_type])

    assert_equal 'cast', expression[:field_manipulations][:function_name]
    assert_equal :function, expression[:field_manipulations][:type]
    assert_equal ['ListPrice', 'character'], expression[:field_manipulations][:args].map {|v| v[:value]}
  end

  def test_cast_with_invalid_type
    parser_errors("cast(ListPrice, 'bogus') Eq '10'")
    parser_errors("ListPrice Eq cast('10', 'bogus')")
  end

  test 'arithmetic literals with functions' do
    @parser = Parser.new
    filter = "Baths Eq 1 Add floor(2.3)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '3', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]

    @parser = Parser.new
    filter = "Baths Eq 1 Add length('asdf')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '5', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]
  end

  test 'arithmetic literals with invalid type' do
    @parser = Parser.new
    filter = "Baths Eq 1 Add '2.3'"
    @parser.parse(filter)
    assert @parser.errors?
  end

  test 'arithmetic literals with invalid function type' do
    @parser = Parser.new
    filter = "Baths Eq 1 Add trim('2.3')"
    @parser.parse(filter)
    assert @parser.errors?
  end

  test 'Add literals' do
    @parser = Parser.new
    filter = "Baths Eq 1 Add 2"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '3', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]

    @parser = Parser.new
    filter = "Baths Eq 1 Add 2 Add 3"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '6', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]
  end

  test 'subtract literals' do
    @parser = Parser.new
    filter = "Baths Eq 10 sub 2"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '8', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]

    @parser = Parser.new
    filter = "Baths Eq 10 sub 2 sub 3"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '5', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]

    @parser = Parser.new
    filter = "Baths Eq 10 sub 2.0 sub 3"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '5.0', expressions.first[:value]
    assert_equal :decimal, expressions.first[:type]
  end

  test 'add and subtract' do
    @parser = Parser.new
    filter = "Baths Eq 10 add 2 sub 2"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '10', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]

    @parser = Parser.new
    filter = "Baths Eq 10 add 2 sub 2.0"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '10.0', expressions.first[:value]
    assert_equal :decimal, expressions.first[:type]
  end

  test 'mul' do
    @parser = Parser.new
    filter = "Baths Eq 5 mul 5"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '25', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]

    @parser = Parser.new
    filter = "Baths Eq 5 mul 5 mul 2"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '50', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]

    @parser = Parser.new
    filter = "Baths Eq 5.0 mul 5 mul 2"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '50.0', expressions.first[:value]
    assert_equal :decimal, expressions.first[:type]
  end

  test 'field operator precedence' do
    @parser = Parser.new
    filter = "Baths add 5 mul 5 Eq 50"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal 'Add', expressions.first[:field_manipulations][:op]
    assert_equal 'Mul', expressions.first[:field_manipulations][:rhs][:op]
  end

  test 'operator precedence' do
    @parser = Parser.new
    filter = "Baths Eq 50 add 5 mul 5"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '75', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]

    @parser = Parser.new
    filter = "Baths Eq 5 mul 5 add 50"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '75', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]

    @parser = Parser.new
    filter = "Baths Eq 50 add 5 div 5"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '51', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]
  end

  test 'modulo' do
    @parser = Parser.new
    filter = "Baths Eq 5 mod 5"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '0', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]

    @parser = Parser.new
    filter = "Baths Eq 5.0 mod 5"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect

    assert_equal '0.0', expressions.first[:value]
    assert_equal :decimal, expressions.first[:type]
  end

  test 'division by zero' do
    parser_errors('Baths Eq 5 mod 0')
    parser_errors('Baths Eq 5 div 0')
  end

  test 'nested functions on field side' do
    @parser = Parser.new
    filter = "tolower(toupper(City)) Eq 'Fargo'"
    expression = @parser.parse(filter).first
    assert_equal 'City', expression[:field]
    assert expression.key?(:field_manipulations)
    function1 = expression[:field_manipulations]
    assert_equal :function, function1[:type]
    assert_equal 'tolower', function1[:function_name]
    assert_equal 'tolower', expression[:field_function]

    function2 = function1[:args].first
    assert_equal :function, function2[:type]
    assert_equal 'toupper', function2[:function_name]
    assert_equal({:type=>:field, :value=>"City"}, function2[:args].first)
  end

  test 'nested functions with multiple params' do
    filter = "concat(tolower(City), 'b') Eq 'fargob'"
    @parser = Parser.new
    expression = @parser.parse(filter).first
    assert expression.key?(:field_manipulations)
    function1 = expression[:field_manipulations]
    assert_equal :function, function1[:type]
    assert_equal 'concat', function1[:function_name]
    assert_equal({type: :character, value: 'b'}, function1[:args].last)

    function2 = function1[:args].first
    assert_equal :function, function2[:type]
    assert_equal 'tolower', function2[:function_name]
    assert_equal({:type=>:field, :value=>"City"}, function2[:args].first)
  end

  test 'parse error with no field' do
    parser_errors("1 Eq 1")
    parser_errors("1 Add 1 Eq 2")
  end

  test "field grouping" do
    @parser = Parser.new
    expressions = @parser.parse('(Test) Eq 10')
    assert !@parser.errors?

    assert_equal 'Group', expressions.first[:field_manipulations][:op]
  end

  test "grouping arithmetic" do
    @parser = Parser.new
    expressions = @parser.parse('(Test mul 10) sub 2 Eq 10')
    assert !@parser.errors?

    assert_equal 'Sub', expressions.first[:field_manipulations][:op]
    assert_equal 'Group', expressions.first[:field_manipulations][:lhs][:op]
  end

  test "grouping literal" do
    @parser = Parser.new
    expressions = @parser.parse('Test Eq (5 sub 5) mul 5 ')
    assert !@parser.errors?

    assert_equal '0', expressions.first[:value]
  end

  test 'Arithmetic grouping should not influence expression grouping' do
    filter = "(BathroomsTotalDecimal add (5 mul 5)) Eq ((3.4 add 2.6) mul (1 add 1))"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?
    assert_equal 0, expressions.first[:level]
    assert_equal 0, expressions.first[:block_group]

    filter = "((BathroomsTotalDecimal add (5 mul 5)) Eq ((3.4 add 2.6) mul (1 add 1))) And BathroomsTotalDecimal Eq 5"
    @parser = Parser.new
    expressions = @parser.parse(filter)
    assert !@parser.errors?
    assert_equal 1, expressions.first[:level]
    assert_equal 1, expressions.first[:block_group]
    assert_equal 0, expressions.last[:level]
    assert_equal 0, expressions.last[:block_group]
  end

  private

  def parser_errors(filter)  
    @parser = Parser.new
    expression = @parser.parse(filter)
    assert @parser.errors?, "Should find errors for '#{filter}': #{expression}"
  end

  def parse(q,v)
    expressions = @parser.parse(q)
    assert !@parser.errors?, "Unexpected error parsing #{q} #{@parser.errors.inspect}"
    assert_equal v, expressions.first[:value], "Expression #{expressions.inspect}"
    assert !expressions.first[:custom_field], "Unexepected custom field #{expressions.inspect}"
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
end
