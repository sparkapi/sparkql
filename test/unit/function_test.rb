require 'test_helper'

# 
class FunctionTest < Test::Unit::TestCase
  include Sparkql

  setup do
    @parser = Parser.new
  end

  test 'tolower takes field' do
    f = get("tolower(City)")
    assert_equal :character, f.return_type
    assert_equal Sparkql::Nodes::Functions::Tolower, f.class
    assert_equal Sparkql::Nodes::Identifier, f.args.first.class
  end

  test 'tolower fails without 1 character parameter' do
    assert_invalid("tolower()")
    assert_invalid("tolower('First', 'Second')")
    assert_invalid("tolower(1)")
  end

  test 'tolower with literal' do
    f = get("tolower('Fargo')")
    assert_equal :character, f.return_type
    assert_equal Sparkql::Nodes::Literal, f.args.first.class
  end

  test 'toupper takes field' do
    f = get("toupper(City)")
    assert_equal :character, f.return_type
    assert_equal Sparkql::Nodes::Functions::Toupper, f.class
    assert_equal Sparkql::Nodes::Identifier, f.args.first.class
  end

  test 'toupper fails without 1 character parameter' do
    assert_invalid("toupper()")
    assert_invalid("toupper('First', 'Second')")
    assert_invalid("toupper(1)")
  end

  test 'toupper with literal' do
    f = get("toupper('Fargo')")
    assert_equal :character, f.return_type
    assert_equal Sparkql::Nodes::Literal, f.args.first.class
  end

  test 'length takes field' do
    f = get("length(City)")
    assert_equal :integer, f.return_type
    assert_equal Sparkql::Nodes::Functions::Length, f.class
    assert_equal Sparkql::Nodes::Identifier, f.args.first.class
  end

  test 'length fails without 1 character parameter' do
    assert_invalid("length()")
    assert_invalid("length('First', 'Second')")
    assert_invalid("length(1)")
  end

  test 'length with literal' do
    f = get("length('Fargo')")
    assert_equal :integer, f.return_type
    assert_equal Sparkql::Nodes::Literal, f.args.first.class
  end

  test 'function months' do
    expressions = @parser.parse "ExpirationDate Gt months(-3)"
    assert !@parser.errors?, "errors :( #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Months, expressions.right.class
    assert_equal(-3, expressions.right.args.first.value)
  end

  test 'function years' do
    expressions = @parser.parse "SoldDate Lt years(2)"
    assert !@parser.errors?, "errors :( #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Years, expressions.right.class
    assert_equal 2, expressions.right.args.first.value
  end

  test 'function days' do
    filter = "OriginalEntryTimestamp Ge days(-7)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Days, expressions.right.class
    assert_equal(-7, expressions.right.args.first.value)
  end

  test 'now requires no parameters' do
    filter = "BeginDate Eq now(1)"
    @parser.parse(filter)
    assert @parser.errors?, @parser.errors.inspect
  end

  test 'function now' do
    filter = "City Eq now()"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Now, expressions.right.class
    assert_equal [], expressions.right.args
  end

  test 'mindatetime requires no parameters' do
    filter = "BeginDate Eq mindatetime(1)"
    @parser.parse(filter)
    assert @parser.errors?, @parser.errors.inspect
  end

  test 'function mindatetime' do
    filter = "City Eq mindatetime()"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Mindatetime, expressions.right.class
    assert_equal [], expressions.right.args
  end

  test 'maxdatetime requires no parameters' do
    filter = "BeginDate Eq maxdatetime(1)"
    @parser.parse(filter)
    assert @parser.errors?, @parser.errors.inspect
  end

  test 'function maxdatetime' do
    filter = "City Eq maxdatetime()"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Maxdatetime, expressions.right.class
    assert_equal [], expressions.right.args
  end

  test 'time(datetime)' do
    filter = "City Eq time(OriginalEntryTimestamp)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Time, expressions.right.class
    assert_equal 'OriginalEntryTimestamp', expressions.right.args.first.value
  end

  test 'date(datetime)' do
    filter = "City Eq date(OriginalEntryTimestamp)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Date, expressions.right.class
    assert_equal 'OriginalEntryTimestamp', expressions.right.args.first.value
  end

  test "startswith(), endswith() and contains()" do
    ['startswith', 'endswith', 'contains'].each do |function|
      filter = "City Eq #{function}('Far')"
      expressions = @parser.parse(filter)
      assert !@parser.errors?, "errors #{@parser.errors.inspect}"

      assert_equal Sparkql::Nodes::Functions.const_get(function.capitalize), expressions.right.class
      assert_equal 'Far', expressions.right.args.first.value
    end
  end

  test 'wkt()' do
    wkt_string = 'SRID=12345;POLYGON((-127.89734578345 45.234534534,-127.89734578345 45.234534534,-127.89734578345 45.234534534,-127.89734578345 45.234534534))'
    filter = "City Eq wkt('#{wkt_string}')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Wkt, expressions.right.class
    assert_equal wkt_string, expressions.right.args.first.value
  end

  test 'function range' do
    filter = "MapCoordinates Eq range('M01','M04')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Range, expressions.right.class
    assert_equal ["M01","M04"], expressions.right.args.map(&:value)
  end

  test "function rangeable " do
    filter = "OriginalEntryTimestamp Bt days(-7),days(-1)"
    expressions = @parser.parse(filter)

    assert_equal Sparkql::Nodes::Between, expressions.class
    assert_equal Array, expressions.right.class
    assert_equal(-7, expressions.right.first.args.first.value)
    assert_equal(-1, expressions.right.last.args.first.value)
  end

  test "multiple function list" do
    filter = "OriginalEntryTimestamp Eq days(-1),days(-7),days(-30)"
    expression = @parser.parse(filter)

    assert_equal Sparkql::Nodes::In, expression.class

    assert_equal 'OriginalEntryTimestamp', expression.left.value
    assert_equal(-1, expression.right[0].args.first.value)
    assert_equal(-7, expression.right[1].args.first.value)
    assert_equal(-30, expression.right[2].args.first.value)
  end

  test 'function date' do
    filter = "OnMarketDate Eq date(OriginalEntryTimestamp)"

    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal Sparkql::Nodes::Functions::Date, expressions.right.class
    assert_equal 'OriginalEntryTimestamp', expressions.right.args.first.value

    # Run using a static value, we just resolve the type
    filter = "OnMarketDate Eq date(2013-07-26T10:22:15.111-0100)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Date, expressions.right.class
    assert_equal DateTime.parse('2013-07-26T10:22:15.111-0100'), expressions.right.args.first.value

    # And the grand finale: run on both sides
    filter = "date(OriginalEntryTimestamp) Eq date(2013-07-26T10:22:15.111-0100)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Date, expressions.right.class
    assert_equal DateTime.parse('2013-07-26T10:22:15.111-0100'), expressions.right.args.first.value

    assert_equal Sparkql::Nodes::Functions::Date, expressions.left.class
    assert_equal 'OriginalEntryTimestamp', expressions.left.args.first.value
  end

  test "regex function parses without second param" do
    filter = "ParcelNumber Eq regex('^[0-9]{3}-[0-9]{2}-[0-9]{3}$')"
    expression = @parser.parse(filter)

    assert_equal Sparkql::Nodes::Functions::Regex, expression.right.class
    assert_equal "^[0-9]{3}-[0-9]{2}-[0-9]{3}$", expression.right.args.first.value
  end

  test "regex function parses with case-insensitive flag" do
    filter = "ParcelNumber Eq regex('^[0-9]{3}-[0-9]{2}-[0-9]{3}$', 'i')"
    expression = @parser.parse(filter)

    assert_equal Sparkql::Nodes::Functions::Regex, expression.right.class
    assert_equal ["^[0-9]{3}-[0-9]{2}-[0-9]{3}$","i"], expression.right.args.map(&:value)
  end

  test "function polygon" do
    filter = "Location Eq polygon('35.12 -68.33, 35.13 -68.33, 35.13 -68.32, 35.12 -68.32')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Polygon, expressions.right.class
    assert_equal "35.12 -68.33, 35.13 -68.33, 35.13 -68.32, 35.12 -68.32", expressions.right.args.first.value
  end

  test "function linestring" do
    filter = "Location Eq linestring('35.12 -68.33, 35.13 -68.33')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Linestring, expressions.right.class
    assert_equal "35.12 -68.33, 35.13 -68.33", expressions.right.args.first.value
  end

  test "function rectangle" do
    filter = "Location Eq rectangle('35.12 -68.33, 35.13 -68.32')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Rectangle, expressions.right.class
    assert_equal "35.12 -68.33, 35.13 -68.32", expressions.right.args.first.value
  end

  test "function radius with decimal" do
    filter = "Location Eq radius('35.12 -68.33',1.0)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Radius, expressions.right.class
    assert_equal ["35.12 -68.33",1.0], expressions.right.args.map(&:value)
  end

  test "function radius accepts integer" do
    filter = "Location Eq radius('35.12 -68.33',1)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Radius, expressions.right.class
    assert_equal ["35.12 -68.33",1], expressions.right.args.map(&:value)
  end

  test "radius() can be overloaded with a ListingKey" do
    filter = "Location Eq radius('20100000000000000000000000',1)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Radius, expressions.right.class
    assert_equal ['20100000000000000000000000', 1], expressions.right.args.map(&:value)
  end

  test 'undefined function' do
    filter = "Location Eq bugus(1)"
    @parser.parse(filter)
    assert @parser.errors?, @parser.errors.inspect
  end

  test 'indexof with field' do
    filter = "indexof(City, '4131800000000') Eq 13"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Indexof, expressions.left.class
    assert_equal Sparkql::Nodes::Identifier, expressions.left.args.first.class
    assert_equal 'City', expressions.left.args.first.value
  end

  test "year(), month(), and day()" do
    ['year', 'month', 'day'].each do |function|
      @parser = Parser.new
      filter = "FieldName Eq #{function}(OriginalEntryTimestamp)"
      @parser.parse(filter)
      assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    end
  end

  test "hour(), minute(), and second()" do
    ['hour', 'minute', 'second'].each do |function|
      @parser = Parser.new
      filter = " FieldName Eq #{function}(OriginalEntryTimestamp)"
      @parser.parse(filter)
      assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    end
  end

  test "fractionalseconds()" do
    filter = "City Eq fractionalseconds(OriginalEntryTimestamp)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal Sparkql::Nodes::Functions::Fractionalseconds, expressions.right.class
    assert_equal 'OriginalEntryTimestamp', expressions.right.args.first.value
  end

  private

  def assert_invalid(function_call)
    @parser = Parser.new
    filter = "City Eq #{function_call}"
    @parser.parse(filter)
    assert @parser.errors?
  end

  def get(function_call)
    @parser = Parser.new
    filter = "City Eq #{function_call}"
    ast = @parser.parse(filter)
    assert !@parser.errors?
    ast.right
  end

end
