require 'test_helper'

class ParserTest < Test::Unit::TestCase
  include Sparkql

  def setup
    @parser = Parser.new
  end

  test 'simple' do
    parse 'Test Eq 10'
    parse 'Test Eq 10.0'
    parse 'Test Eq true'
    parse "Test Eq 'false'"
  end

  test "And conjunction" do
    expression = @parser.parse('Test Eq 10 And Test Ne 11')
    assert_equal 10, expression.left.right.value
    assert_equal 11, expression.right.right.value
    assert_equal Sparkql::Nodes::And, expression.class
  end

  test "Or conjunction" do
    expression = @parser.parse('Test Eq 10 Or Test Ne 11')
    assert_equal 10, expression.left.right.value
    assert_equal 11, expression.right.right.value
    assert_equal Sparkql::Nodes::Or, expression.class
  end

  test "Not conjunction" do
    expression = @parser.parse('Test Eq 10 Not Test Ne 11')
    assert_equal 10, expression.left.right.value
    assert_equal 11, expression.right.value.right.value
    assert_equal Sparkql::Nodes::And, expression.class
    assert_equal Sparkql::Nodes::Not, expression.right.class
  end

  test 'touch conjunction' do
    expression = @parser.parse('Test Eq 10 Or Test Ne 11 And Test Ne 9')
    and_expr = expression
    or_expr = and_expr.left

    assert_equal Sparkql::Nodes::And, and_expr.class
    assert_equal Sparkql::Nodes::Or, or_expr.class
    assert_equal 10, or_expr.left.right.value
    assert_equal 11, or_expr.right.right.value
  end

  test 'grouping' do
    expression = @parser.parse('(Test Eq 10)')
    assert_equal 10, expression.value.right.value

    expression = @parser.parse('(Test Eq 10 Or Test Ne 11)')
    assert_equal 10, expression.value.left.right.value
    assert_equal 11, expression.value.right.right.value
    assert_equal Sparkql::Nodes::Or, expression.value.class

    expression = @parser.parse('(Test Eq 10 Or (Test Ne 11))')
    assert_equal 10, expression.value.left.right.value
    assert_equal 11, expression.value.right.value.right.value
    assert_equal Sparkql::Nodes::Or, expression.value.class
  end

  test 'multiple Eq' do
    expression = @parser.parse('Test Eq 10,11,12')
    assert_equal Sparkql::Nodes::In, expression.class

    assert_equal 'Test', expression.left.value
    assert_equal 10, expression.right[0].value
    assert_equal 11, expression.right[1].value
    assert_equal 12, expression.right[2].value
  end

  test 'multiple Ne' do
    expression = @parser.parse('Test Ne 10,11,12')
    assert_equal Sparkql::Nodes::Not, expression.class
    assert_equal Sparkql::Nodes::In, expression.value.class

    assert_equal 'Test', expression.value.left.value
    assert_equal 10, expression.value.right[0].value
    assert_equal 11, expression.value.right[1].value
    assert_equal 12, expression.value.right[2].value
  end

  test 'invalid syntax' do
    expression = @parser.parse('Test Eq DERP')
    assert @parser.errors?, "Should be nil: #{expression}"
  end

  test 'nesting' do
    expression = @parser.parse("City Eq 'Fargo' Or (BathsFull Eq 1 Or BathsFull Eq 2) Or City Eq 'Moorhead' Or City Eq 'Dilworth'")
    city_or = expression
    assert_equal Sparkql::Nodes::Or, city_or.class

    baths_or_cities = expression.left
    assert_equal Sparkql::Nodes::Or, baths_or_cities.class

    city_or_baths = expression.left.left
    assert_equal Sparkql::Nodes::Or, city_or_baths.class

    baths_1_or_2 = expression.left.left.right
    assert_equal Sparkql::Nodes::Group, baths_1_or_2.class
    assert_equal 1, baths_1_or_2.value.left.right.value
  end

  test 'multilevel nesting' do
    filter = "((City Eq 'Fargo'))"
    expression = @parser.parse(filter)

    assert_equal Sparkql::Nodes::Group, expression.class
    assert_equal Sparkql::Nodes::Group, expression.value.class
    assert_not_equal Sparkql::Nodes::Group, expression.value.value.class
  end

  test 'bad queries' do
    filter = "City IsLikeA 'Town'"
    expressions = @parser.parse(filter)
    assert @parser.errors?, "Should be nil: #{expressions}"
    assert @parser.fatal_errors?, "Should be nil: #{@parser.errors.inspect}"
  end

  test "mixed rangeable " do
    filter = "OriginalEntryTimestamp Bt days(-7),2013-07-26"
    expressions = @parser.parse(filter)

    assert_equal Sparkql::Nodes::Between, expressions.class
    assert_equal Array, expressions.right.class
    assert_equal(-7, expressions.right.first.args.first.value)
    assert_equal(Date.parse('2013-07-26'), expressions.right.last.value)
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
      expressions = @parser.parse(filter)
      assert !@parser.errors?, "errors #{@parser.errors.inspect}"
      assert_not_nil expressions, "#{value} failed"
      assert_equal DateTime.parse(value), expressions.right.value, "#{value} failed"
    end
  end

  test 'reserved words first literals second' do
    ["OrOrOr Eq true", "Equador Eq true", "Oregon Ge 10"].each do |filter|
      @parser.parse(filter)
      assert !@parser.errors?, "Filter '#{filter}' errors: #{@parser.errors.inspect}"
    end
  end

  test 'custom fields' do
    filter = '"General Property Description"."Taxes" Lt 500.0'
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::CustomIdentifier, expressions.left.class
    assert_equal '"General Property Description"."Taxes"', expressions.left.value
  end

  test 'valid custom field filters' do
    ['"General Property Description"."Taxes$" Lt 500.0',
      '"General Property Desc\'"."Taxes" Lt 500.0',
      '"General Property Description"."Taxes" Lt 500.0',
      '"General \'Property\' Description"."Taxes" Lt 500.0',
      '"General Property Description"."Taxes #" Lt 500.0',
      '"General$Description"."Taxes" Lt 500.0',
      '"Garage Type"."1" Eq true',
      '" a "." b " Lt 500.0'
    ].each do |filter|
      @parser.parse(filter)
      assert !@parser.errors?, "errors '#{filter}'\n#{@parser.errors.inspect}"
    end
  end

  test 'invalid custom field filters' do
    ['"$General Property Description"."Taxes" Lt 500.0',
      '"General Property Description"."$Taxes" Lt 500.0',
      '"General Property Description"."Tax.es" Lt 500.0',
      '"General Property Description".".Taxes" Lt 500.0',
      '"General Property Description".".Taxes"."SUB" Lt 500.0',
      '"General.Description"."Taxes" Lt 500.0',
      '""."" Lt 500.0'
    ].each do |filter|
      @parser.parse(filter)
      assert @parser.errors?, "No errors? '#{filter}'\n#{@parser.inspect}"
    end
  end

  test 'case insensitive ops and conjucntions' do
    parse 'Test EQ 10'
    parse 'Test eq 10.0'
    parse 'Test eQ true'
    parse 'Test EQ 10 AND Test NE 11'
    parse 'Test eq 10 or Test ne 11'
    parse 'Test eq 10 NOT Test ne 11'
  end

  test 'null' do
    expressions = parse('Test Eq NULL')
    assert_equal nil, expressions.right.value
    assert_equal :null, expressions.right.type
  end

  test 'not expression group' do
    expression = @parser.parse('Not (Test Eq 10 Or Test Eq 11)')
    assert !@parser.errors?, @parser.inspect
    assert_equal Sparkql::Nodes::Not, expression.class
    assert_equal Sparkql::Nodes::Group, expression.value.class
  end

  test 'not unary expression' do
    expression = @parser.parse('Not Test Eq 10')
    assert !@parser.errors?, @parser.inspect

    assert_equal Sparkql::Nodes::Not, expression.class
    assert_equal Sparkql::Nodes::Equal, expression.value.class
  end

  test 'not expression' do
    expression = @parser.parse('Test Lt 10 Not Test Eq 2')
    assert !@parser.errors?, @parser.inspect
    assert_equal Sparkql::Nodes::And, expression.class
    assert_equal Sparkql::Nodes::Not, expression.right.class
  end

  test 'not not' do
    filter = "Not (Not ListPrice Eq 1)"
    expression = parse(filter)
    assert_equal Sparkql::Nodes::Not, expression.class
    assert_equal Sparkql::Nodes::Not, expression.value.value.class
  end

  test 'unary not with and' do
    filter = "Not ListPrice Eq 1 And ListPrice Eq 1"
    expression = parse(filter)
    assert_equal Sparkql::Nodes::And, expression.class
    assert_equal Sparkql::Nodes::Not, expression.left.class
  end

  test 'bad string?' do
    parser_errors("Test Eq BADSTRING")
  end

  test 'datetimes as ranges' do
    ["DatetimeField Bt 2013-07-26T10:22:15.422804,2013-07-26T10:22:15.422805",
     "DateTimeField Bt 2013-07-26T10:22:15,2013-07-26T10:22:16",
     "DateTimeField Bt 2013-07-26T10:22:15.422804-0300,2013-07-26T10:22:15.422805-0300",
     "DateTimeField Bt 2013-07-26T10:22:15+0400,2013-07-26T10:22:16+0400"].each do |filter|
      @parser.parse filter
      assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"
     end
  end

  test "only eq and ne accept multiple values" do
    ["Gt","Ge","Lt","Le"].each do |op|
      f = "IntegerType #{op} 100,200" 
      parser = Parser.new
      parser.parse( f )
      assert parser.errors?
      assert_equal op, parser.errors.first.token
    end
  end

  test "eq and ne accept multiple values" do
    ['Eq', 'Ne'].each do |op|
      f = "IntegerType #{op} 100,200" 
      parser = Parser.new
      parser.parse( f )
      assert !parser.errors?
    end
  end

  test "fail on missing" do
    filter = "City Eq 'Fargo' And PropertyType Eq 'A'"
    filter_tokens = filter.split(" ")

    filter_tokens.each do |token|
      f = filter.gsub(token, "").gsub(/\s+/," ")
      parser = Parser.new
      expressions = parser.tokenize( f )
      assert_nil expressions
      assert parser.errors?
    end
  end

  private

  def parse(q)
    @parser = Parser.new
    node = @parser.parse(q)
    assert !@parser.errors?, "Unexpected error parsing #{q} #{@parser.errors.inspect}"
    node
  end

  def parser_errors(filter)
    @parser = Parser.new
    expression = @parser.parse(filter)
    assert @parser.errors?, "Should find errors for '#{filter}': #{expression}"
  end

end
