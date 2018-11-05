# frozen_string_literal: true

require 'test_helper'

class FunctionTest < Test::Unit::TestCase
  include SparkqlV2

  setup do
    @parser = Parser.new
  end

  test 'tolower takes field' do
    f = get('tolower(City)')
    assert_equal 'tolower', f['name']
    assert_equal 'field', f['args'].first['name']
  end

  test 'tolower with literal' do
    f = get("tolower('Fargo')")
    assert_equal 'literal', f['args'].first['name']
  end

  test 'toupper takes field' do
    f = get('toupper(City)')
    assert_equal 'toupper', f['name']
    assert_equal 'field', f['args'].first['name']
  end

  test 'toupper with literal' do
    f = get("toupper('Fargo')")
    assert_equal 'literal', f['args'].first['name']
  end

  test 'length takes field' do
    f = get('length(City)')
    assert_equal 'length', f['name']
    assert_equal 'field', f['args'].first['name']
  end

  test 'length with literal' do
    f = get("length('Fargo')")
    assert_equal 'literal', f['args'].first['name']
  end

  test 'function months' do
    expressions = @parser.parse 'ExpirationDate Gt months(-3)'
    assert !@parser.errors?, "errors :( #{@parser.errors.inspect}"

    assert_equal 'months', expressions['rhs']['name']
    assert_equal(-3, expressions['rhs']['args'].first['value'])
  end

  test 'function years' do
    expressions = @parser.parse 'SoldDate Lt years(2)'
    assert !@parser.errors?, "errors :( #{@parser.errors.inspect}"

    assert_equal 'years', expressions['rhs']['name']
    assert_equal 2, expressions['rhs']['args'].first['value']
  end

  test 'function days' do
    filter = 'OriginalEntryTimestamp Ge days(-7)'
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'days', expressions['rhs']['name']
    assert_equal(-7, expressions['rhs']['args'].first['value'])
  end

  test 'function now' do
    filter = 'City Eq now()'
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'now', expressions['rhs']['name']
    assert_equal [], expressions['rhs']['args']
  end

  test 'function mindatetime' do
    filter = 'City Eq mindatetime()'
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'mindatetime', expressions['rhs']['name']
    assert_equal [], expressions['rhs']['args']
  end

  test 'function maxdatetime' do
    filter = 'City Eq maxdatetime()'
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'maxdatetime', expressions['rhs']['name']
    assert_equal [], expressions['rhs']['args']
  end

  test 'time(datetime)' do
    filter = 'City Eq time(OriginalEntryTimestamp)'
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'time', expressions['rhs']['name']
    assert_equal 'OriginalEntryTimestamp', expressions['rhs']['args'].first['value']
  end

  test 'date(datetime)' do
    filter = 'City Eq date(OriginalEntryTimestamp)'
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'date', expressions['rhs']['name']
    assert_equal 'OriginalEntryTimestamp', expressions['rhs']['args'].first['value']
  end

  test 'startswith(), endswith() and contains()' do
    %w[startswith endswith contains].each do |function|
      filter = "City Eq #{function}('Far')"
      expressions = @parser.parse(filter)
      assert !@parser.errors?, "errors #{@parser.errors.inspect}"

      assert_equal function, expressions['rhs']['name']
      assert_equal 'Far', expressions['rhs']['args'].first['value']
    end
  end

  test 'wkt()' do
    wkt_string = 'SRID=12345;POLYGON((-127.89734578345 45.234534534,-127.89734578345 45.234534534,-127.89734578345 45.234534534,-127.89734578345 45.234534534))'
    filter = "City Eq wkt('#{wkt_string}')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'wkt', expressions['rhs']['name']
    assert_equal wkt_string, expressions['rhs']['args'].first['value']
  end

  test 'function range' do
    filter = "MapCoordinates Eq range('M01','M04')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'range', expressions['rhs']['name']
    assert_equal %w[M01 M04], expressions['rhs']['args'].map { |v| v['value'] }
  end

  test 'function rangeable ' do
    filter = 'OriginalEntryTimestamp Bt days(-7),days(-1)'
    expressions = @parser.parse(filter)

    assert_equal 'bt', expressions['name']
    assert_equal Array, expressions['rhs'].class
    assert_equal(-7, expressions['rhs'].first['args'].first['value'])
    assert_equal(-1, expressions['rhs'].last['args'].first['value'])
  end

  test 'multiple function list' do
    filter = 'OriginalEntryTimestamp Eq days(-1),days(-7),days(-30)'
    expression = @parser.parse(filter)

    assert_equal 'in', expression['name']

    assert_equal 'OriginalEntryTimestamp', expression['lhs']['value']
    assert_equal(-1, expression['rhs'][0]['args'].first['value'])
    assert_equal(-7, expression['rhs'][1]['args'].first['value'])
    assert_equal(-30, expression['rhs'][2]['args'].first['value'])
  end

  test 'function date' do
    filter = 'OnMarketDate Eq date(OriginalEntryTimestamp)'

    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    assert_equal 'date', expressions['rhs']['name']
    assert_equal 'OriginalEntryTimestamp', expressions['rhs']['args'].first['value']

    # Run using a static value, we just resolve the type
    filter = 'OnMarketDate Eq date(2013-07-26T10:22:15.111-0100)'
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'date', expressions['rhs']['name']
    assert_equal DateTime.parse('2013-07-26T10:22:15.111-0100'), expressions['rhs']['args'].first['value']

    # And the grand finale: run on both sides
    filter = 'date(OriginalEntryTimestamp) Eq date(2013-07-26T10:22:15.111-0100)'
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'date', expressions['rhs']['name']
    assert_equal DateTime.parse('2013-07-26T10:22:15.111-0100'), expressions['rhs']['args'].first['value']

    assert_equal 'date', expressions['lhs']['name']
    assert_equal 'OriginalEntryTimestamp', expressions['lhs']['args'].first['value']
  end

  test 'regex function parses without second param' do
    filter = "ParcelNumber Eq regex('^[0-9]{3}-[0-9]{2}-[0-9]{3}$')"
    expression = @parser.parse(filter)

    assert_equal 'regex', expression['rhs']['name']
    assert_equal '^[0-9]{3}-[0-9]{2}-[0-9]{3}$', expression['rhs']['args'].first['value']
  end

  test 'regex function parses with case-insensitive flag' do
    filter = "ParcelNumber Eq regex('^[0-9]{3}-[0-9]{2}-[0-9]{3}$', 'i')"
    expression = @parser.parse(filter)

    assert_equal 'regex', expression['rhs']['name']
    assert_equal ['^[0-9]{3}-[0-9]{2}-[0-9]{3}$', 'i'], expression['rhs']['args'].map { |v| v['value'] }
  end

  test 'function polygon' do
    filter = "Location Eq polygon('35.12 -68.33, 35.13 -68.33, 35.13 -68.32, 35.12 -68.32')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'polygon', expressions['rhs']['name']
    assert_equal '35.12 -68.33, 35.13 -68.33, 35.13 -68.32, 35.12 -68.32', expressions['rhs']['args'].first['value']
  end

  test 'function linestring' do
    filter = "Location Eq linestring('35.12 -68.33, 35.13 -68.33')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'linestring', expressions['rhs']['name']
    assert_equal '35.12 -68.33, 35.13 -68.33', expressions['rhs']['args'].first['value']
  end

  test 'function rectangle' do
    filter = "Location Eq rectangle('35.12 -68.33, 35.13 -68.32')"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'rectangle', expressions['rhs']['name']
    assert_equal '35.12 -68.33, 35.13 -68.32', expressions['rhs']['args'].first['value']
  end

  test 'function radius with decimal' do
    filter = "Location Eq radius('35.12 -68.33',1.0)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'radius', expressions['rhs']['name']
    assert_equal ['35.12 -68.33', 1.0], expressions['rhs']['args'].map { |v| v['value'] }
  end

  test 'function radius accepts integer' do
    filter = "Location Eq radius('35.12 -68.33',1)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'radius', expressions['rhs']['name']
    assert_equal ['35.12 -68.33', 1], expressions['rhs']['args'].map { |v| v['value'] }
  end

  test 'radius() can be overloaded with a ListingKey' do
    filter = "Location Eq radius('20100000000000000000000000',1)"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'radius', expressions['rhs']['name']
    assert_equal ['20100000000000000000000000', 1], expressions['rhs']['args'].map { |v| v['value'] }
  end

  test 'indexof with field' do
    filter = "indexof(City, '4131800000000') Eq 13"
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'indexof', expressions['lhs']['name']
    assert_equal 'field', expressions['lhs']['args'].first['name']
    assert_equal 'City', expressions['lhs']['args'].first['value']
  end

  test 'year(), month(), and day()' do
    %w[year month day].each do |function|
      @parser = Parser.new
      filter = "FieldName Eq #{function}(OriginalEntryTimestamp)"
      @parser.parse(filter)
      assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    end
  end

  test 'hour(), minute(), and second()' do
    %w[hour minute second].each do |function|
      @parser = Parser.new
      filter = " FieldName Eq #{function}(OriginalEntryTimestamp)"
      @parser.parse(filter)
      assert !@parser.errors?, "errors #{@parser.errors.inspect}"
    end
  end

  test 'fractionalseconds()' do
    filter = 'City Eq fractionalseconds(OriginalEntryTimestamp)'
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'fractionalseconds', expressions['rhs']['name']
    assert_equal 'OriginalEntryTimestamp', expressions['rhs']['args'].first['value']
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
    ast['rhs']
  end
end
