require 'test_helper'

=begin
We _could_ do this validation while parsing, but then we have to do it again for identifiers.

TODO: Need to do this when validating with metadata (need field types as well)
  def test_invalid_operators
    (Sparkql::Token::OPERATORS - Sparkql::Token::EQUALITY_OPERATORS).each do |o|
      ["NULL", "true", "'My String'"].each do |v|
        parser_errors("Test #{o} #{v}")
      end
    end
  end
=end


# TODO: Test function resolutions
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

  test 'multiples' do
    expression = @parser.parse('Test Eq 10,11,12')
    assert_equal Sparkql::Nodes::Or, expression.class
    assert_equal Sparkql::Nodes::Or, expression.left.class
    assert_equal 'Test', expression.right.left.value
    assert_equal 10, expression.right.right.value

    assert_equal 'Test', expression.left.right.left.value
    assert_equal 11, expression.left.right.right.value

    assert_equal 'Test', expression.left.left.left.value
    assert_equal 12, expression.left.left.right.value
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

  test 'function months' do
    expressions = @parser.parse "ExpirationDate Gt months(-3)"
    assert !@parser.errors?, "errors :( #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'months', expressions.right.name
    assert_equal(-3, expressions.right.args.first.value)
  end

  test 'function years' do
    expressions = @parser.parse "SoldDate Lt years(2)"
    assert !@parser.errors?, "errors :( #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'years', expressions.right.name
    assert_equal 2, expressions.right.args.first.value
  end

  test 'function days' do
    filter = "OriginalEntryTimestamp Ge days(-7)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'days', expressions.right.name
    assert_equal(-7, expressions.right.args.first.value)
  end

  test 'function now' do
    filter = "City Eq now()"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'now', expressions.right.name
    assert_equal [], expressions.right.args
  end

  test 'function range' do
    filter = "MapCoordinates Eq range('M01','M04')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'range', expressions.right.name
    assert_equal ["M01","M04"], expressions.right.args.map(&:value)
  end

  test 'indexof with field' do
    filter = "indexof(City, '4131800000000') Eq 13"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.left.class
    assert_equal 'indexof', expressions.left.name
    assert_equal Sparkql::Nodes::Identifier, expressions.left.args.first.class
    assert_equal 'City', expressions.left.args.first.value
  end

  test "function rangeable " do
    filter = "OriginalEntryTimestamp Bt days(-7),days(-1)"
    expressions = @parser.parse(filter)

    assert_equal Sparkql::Nodes::Between, expressions.class
    assert_equal Array, expressions.right.class
    assert_equal(-7, expressions.right.first.args.first.value)
    assert_equal(-1, expressions.right.last.args.first.value)
  end

  test "mixed rangeable " do
    filter = "OriginalEntryTimestamp Bt days(-7),2013-07-26"
    expressions = @parser.parse(filter)

    assert_equal Sparkql::Nodes::Between, expressions.class
    assert_equal Array, expressions.right.class
    assert_equal(-7, expressions.right.first.args.first.value)
    assert_equal(Date.parse('2013-07-26'), expressions.right.last.value)
  end

  test "multiple function list" do
    filter = "OriginalEntryTimestamp Eq days(-1),days(-7),days(-30)"
    expression = @parser.parse(filter)

    assert_equal Sparkql::Nodes::Or, expression.class
    assert_equal Sparkql::Nodes::Or, expression.left.class

    assert_equal 'OriginalEntryTimestamp', expression.right.left.value
    assert_equal(-1, expression.right.right.args.first.value)

    assert_equal 'OriginalEntryTimestamp', expression.left.right.left.value
    assert_equal(-7, expression.left.right.right.args.first.value)

    assert_equal 'OriginalEntryTimestamp', expression.left.left.left.value
    assert_equal(-30, expression.left.left.right.args.first.value)
  end

  test 'function date' do
    filter = "OnMarketDate Eq date(OriginalEntryTimestamp)"

    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'date', expressions.right.name
    assert_equal 'OriginalEntryTimestamp', expressions.right.args.first.value

    # Run using a static value, we just resolve the type
    filter = "OnMarketDate Eq date(2013-07-26T10:22:15.111-0100)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'date', expressions.right.name
    assert_equal DateTime.parse('2013-07-26T10:22:15.111-0100'), expressions.right.args.first.value

    # And the grand finale: run on both sides
    filter = "date(OriginalEntryTimestamp) Eq date(2013-07-26T10:22:15.111-0100)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'date', expressions.right.name
    assert_equal DateTime.parse('2013-07-26T10:22:15.111-0100'), expressions.right.args.first.value

    assert_equal Sparkql::Nodes::Function, expressions.left.class
    assert_equal 'date', expressions.left.name
    assert_equal 'OriginalEntryTimestamp', expressions.left.args.first.value
  end

  test "regex function parses without second param" do
    filter = "ParcelNumber Eq regex('^[0-9]{3}-[0-9]{2}-[0-9]{3}$')"
    expression = @parser.parse(filter)

    assert_equal Sparkql::Nodes::Function, expression.right.class
    assert_equal 'regex', expression.right.name
    assert_equal "^[0-9]{3}-[0-9]{2}-[0-9]{3}$", expression.right.args.first.value
  end

  test "regex function parses with case-insensitive flag" do
    filter = "ParcelNumber Eq regex('^[0-9]{3}-[0-9]{2}-[0-9]{3}$', 'i')"
    expression = @parser.parse(filter)

    assert_equal Sparkql::Nodes::Function, expression.right.class
    assert_equal 'regex', expression.right.name
    assert_equal ["^[0-9]{3}-[0-9]{2}-[0-9]{3}$","i"], expression.right.args.map(&:value)
  end

  test "invalid regex" do
    filter = "ParcelNumber Eq regex('[1234', '')"
    @parser = Parser.new
    @parser.parse(filter)
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
      expressions = @parser.parse(filter)
      assert !@parser.errors?, "errors #{@parser.errors.inspect}"
      assert_not_nil expressions, "#{value} failed"
      assert_equal DateTime.parse(value), expressions.right.value, "#{value} failed"
    end
  end

  test "function polygon" do
    filter = "Location Eq polygon('35.12 -68.33, 35.13 -68.33, 35.13 -68.32, 35.12 -68.32')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'polygon', expressions.right.name
    assert_equal "35.12 -68.33, 35.13 -68.33, 35.13 -68.32, 35.12 -68.32", expressions.right.args.first.value
  end

  test "function linestring" do
    filter = "Location Eq linestring('35.12 -68.33, 35.13 -68.33')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'linestring', expressions.right.name
    assert_equal "35.12 -68.33, 35.13 -68.33", expressions.right.args.first.value
  end

  test "function rectangle" do
    filter = "Location Eq rectangle('35.12 -68.33, 35.13 -68.32')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'rectangle', expressions.right.name
    assert_equal "35.12 -68.33, 35.13 -68.32", expressions.right.args.first.value
  end

  test "function radius" do
    filter = "Location Eq radius('35.12 -68.33',1.0)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'radius', expressions.right.name
    assert_equal ["35.12 -68.33",1.0], expressions.right.args.map(&:value)
  end

  test "function radius accepts integer" do
    filter = "Location Eq radius('35.12 -68.33',1)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Function, expressions.right.class
    assert_equal 'radius', expressions.right.name
    assert_equal ["35.12 -68.33",1], expressions.right.args.map(&:value)
  end

=begin
  test "function radius error on invalid syntax" do
    filter = "Location Eq radius('35.12,-68.33',1.0)"
    @parser.parse(filter)
    assert @parser.errors?, "Parser error expected due to comma between radius points"
  end
=end

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

    assert_equal Sparkql::Nodes::Identifier, expressions.left.class
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

  test 'bad filters' do
    parser_errors("Test Eq BADSTRING")
    parser_errors("Test Eq radius('46.8 -96.8',-20.0)")
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

  test 'coercible types' do
    @parser = Parser.new
    assert_equal :datetime, @parser.coercible_types(:date, :datetime)
    assert_equal :datetime, @parser.coercible_types(:datetime, :date)
    assert_equal :decimal, @parser.coercible_types(:decimal, :integer)
    assert_equal :decimal, @parser.coercible_types(:integer, :decimal)
    # That covers the gambit, anything else should be null
    assert_nil @parser.coercible_types(:integer, :date)
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
