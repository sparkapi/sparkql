# frozen_string_literal: true

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

  test 'And conjunction' do
    expression = @parser.parse('Test Eq 10 And Test Ne 11')
    assert_equal 10, expression['lhs']['rhs']['value']
    assert_equal 11, expression['rhs']['rhs']['value']
    assert_equal 'and', expression['name']
  end

  test 'Or conjunction' do
    expression = @parser.parse('Test Eq 10 Or Test Ne 11')
    assert_equal 10, expression['lhs']['rhs']['value']
    assert_equal 11, expression['rhs']['rhs']['value']
    assert_equal 'or', expression['name']
  end

  test 'Not conjunction' do
    expression = @parser.parse('Test Eq 10 Not Test Ne 11')
    assert_equal 10, expression['lhs']['rhs']['value']
    assert_equal 11, expression['rhs']['value']['rhs']['value']
    assert_equal 'and', expression['name']
    assert_equal 'unary_not', expression['rhs']['name']
  end

  test 'touch conjunction' do
    expression = @parser.parse('Test Eq 10 Or Test Ne 11 And Test Ne 9')
    and_expr = expression
    or_expr = and_expr['lhs']

    assert_equal 'and', and_expr['name']
    assert_equal 'or', or_expr['name']
    assert_equal 10, or_expr['lhs']['rhs']['value']
    assert_equal 11, or_expr['rhs']['rhs']['value']
  end

  test 'grouping' do
    expression = @parser.parse('(Test Eq 10)')
    assert_equal 10, expression['value']['rhs']['value']

    expression = @parser.parse('(Test Eq 10 Or Test Ne 11)')
    assert_equal 10, expression['value']['lhs']['rhs']['value']
    assert_equal 11, expression['value']['rhs']['rhs']['value']
    assert_equal 'or', expression['value']['name']

    expression = @parser.parse('(Test Eq 10 Or (Test Ne 11))')
    assert_equal 10, expression['value']['lhs']['rhs']['value']
    assert_equal 11, expression['value']['rhs']['value']['rhs']['value']
    assert_equal 'or', expression['value']['name']
  end

  test 'multiple Eq' do
    expression = @parser.parse('Test Eq 10,11,12')
    assert_equal 'in', expression['name']

    assert_equal 'Test', expression['lhs']['value']
    assert_equal 10, expression['rhs'][0]['value']
    assert_equal 11, expression['rhs'][1]['value']
    assert_equal 12, expression['rhs'][2]['value']
  end

  test 'multiple Ne' do
    expression = @parser.parse('Test Ne 10,11,12')
    assert_equal 'unary_not', expression['name']
    assert_equal 'in', expression['value']['name']

    assert_equal 'Test', expression['value']['lhs']['value']
    assert_equal 10, expression['value']['rhs'][0]['value']
    assert_equal 11, expression['value']['rhs'][1]['value']
    assert_equal 12, expression['value']['rhs'][2]['value']
  end

  test 'invalid syntax' do
    expression = @parser.parse('Test Eq DERP')
    assert @parser.errors?, "Should be nil: #{expression}"
  end

  test 'nesting' do
    expression = @parser.parse("City Eq 'Fargo' Or (BathsFull Eq 1 Or BathsFull Eq 2) Or City Eq 'Moorhead' Or City Eq 'Dilworth'")
    city_or = expression
    assert_equal 'or', city_or['name']

    baths_or_cities = expression['lhs']
    assert_equal 'or', baths_or_cities['name']

    city_or_baths = expression['lhs']['lhs']
    assert_equal 'or', city_or_baths['name']

    baths_1_or_2 = expression['lhs']['lhs']['rhs']
    assert_equal 'group', baths_1_or_2['name']
    assert_equal 1, baths_1_or_2['value']['lhs']['rhs']['value']
  end

  test 'multilevel nesting' do
    filter = "((City Eq 'Fargo'))"
    expression = @parser.parse(filter)

    assert_equal 'group', expression['name']
    assert_equal 'group', expression['value']['name']
    assert_not_equal 'group', expression['value']['value']['name']
  end

  test 'bad queries' do
    filter = "City IsLikeA 'Town'"
    expressions = @parser.parse(filter)
    assert @parser.errors?, "Should be nil: #{expressions}"
    assert @parser.fatal_errors?, "Should be nil: #{@parser.errors.inspect}"
  end

  test 'mixed rangeable ' do
    filter = 'OriginalEntryTimestamp Bt days(-7),2013-07-26'
    expressions = @parser.parse(filter)

    assert_equal 'bt', expressions['name']
    assert_equal(-7, expressions['rhs'].first['args'].first['value'])
    assert_equal(Date.parse('2013-07-26'), expressions['rhs'].last['value'])
  end

  test 'allow timezone offsets' do
    values = [
      '2013-07-26',
      '10:22',
      '10:22:15.1111',
      '10:22:15',
      '2013-07-26T10:22',
      '2013-07-26T10:22Z',
      '2013-07-26T10:22+01:00',
      '2013-07-26T10:22:15+01:00',
      '2013-07-26T10:22:15.1-01:00',
      '2013-07-26T10:22:15.11+0100',
      '2013-07-26T10:22:15.111-0100',
      '2013-07-26T10:22:15.1111Z',
      '2013-07-26T10:22:15.11111+01:00',
      '2013-07-26T10:22:15.111111+01:00'
    ]
    values.each do |value|
      filter = "DatetimeField Eq #{value}"
      expressions = @parser.parse(filter)
      assert !@parser.errors?, "errors #{@parser.errors.inspect}"
      assert_not_nil expressions, "#{value} failed"
      assert_equal DateTime.parse(value), expressions['rhs']['value'], "#{value} failed"
    end
  end

  test 'reserved words first literals second' do
    ['OrOrOr Eq true', 'Equador Eq true', 'Oregon Ge 10'].each do |filter|
      @parser.parse(filter)
      assert !@parser.errors?, "Filter '#{filter}' errors: #{@parser.errors.inspect}"
    end
  end

  test 'custom fields' do
    filter = '"General Property Description"."Taxes" Lt 500.0'
    expressions = @parser.parse(filter)
    assert !@parser.errors?, "errors #{@parser.errors.inspect}"

    assert_equal 'custom_field', expressions['lhs']['name']
    assert_equal '"General Property Description"."Taxes"', expressions['lhs']['value']
  end

  test 'valid custom field filters' do
    ['"General Property Description"."Taxes$" Lt 500.0',
     '"General Property Desc\'"."Taxes" Lt 500.0',
     '"General Property Description"."Taxes" Lt 500.0',
     '"General \'Property\' Description"."Taxes" Lt 500.0',
     '"General Property Description"."Taxes #" Lt 500.0',
     '"General$Description"."Taxes" Lt 500.0',
     '"Garage Type"."1" Eq true',
     '" a "." b " Lt 500.0'].each do |filter|
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
     '""."" Lt 500.0'].each do |filter|
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
    assert_equal nil, expressions['rhs']['value']
    assert_equal 'null', expressions['rhs']['type']
  end

  test 'not expression group' do
    expression = @parser.parse('Not (Test Eq 10 Or Test Eq 11)')
    assert !@parser.errors?, @parser.inspect
    assert_equal 'unary_not', expression['name']
    assert_equal 'group', expression['value']['name']
  end

  test 'not unary expression' do
    expression = @parser.parse('Not Test Eq 10')
    assert !@parser.errors?, @parser.inspect

    assert_equal 'unary_not', expression['name']
    assert_equal 'eq', expression['value']['name']
  end

  test 'not expression' do
    expression = @parser.parse('Test Lt 10 Not Test Eq 2')
    assert !@parser.errors?, @parser.inspect
    assert_equal 'and', expression['name']
    assert_equal 'unary_not', expression['rhs']['name']
  end

  test 'not not' do
    filter = 'Not (Not ListPrice Eq 1)'
    expression = parse(filter)
    assert_equal 'unary_not', expression['name']
    assert_equal 'unary_not', expression['value']['value']['name']
  end

  test 'unary not with and' do
    filter = 'Not ListPrice Eq 1 And ListPrice Eq 1'
    expression = parse(filter)
    assert_equal 'and', expression['name']
    assert_equal 'unary_not', expression['lhs']['name']
  end

  test 'bad string?' do
    parser_errors('Test Eq BADSTRING')
  end

  test 'datetimes as ranges' do
    ['DatetimeField Bt 2013-07-26T10:22:15.422804,2013-07-26T10:22:15.422805',
     'DateTimeField Bt 2013-07-26T10:22:15,2013-07-26T10:22:16',
     'DateTimeField Bt 2013-07-26T10:22:15.422804-0300,2013-07-26T10:22:15.422805-0300',
     'DateTimeField Bt 2013-07-26T10:22:15+0400,2013-07-26T10:22:16+0400'].each do |filter|
       @parser.parse filter
       assert !@parser.errors?, "Filter '#{filter}' failed: #{@parser.errors.first.inspect}"
     end
  end

  test 'only eq and ne accept multiple values' do
    %w[Gt Ge Lt Le].each do |op|
      f = "IntegerType #{op} 100,200"
      parser = Parser.new
      parser.parse(f)
      assert parser.errors?
      assert_equal op, parser.errors.first.token
    end
  end

  test 'eq and ne accept multiple values' do
    %w[Eq Ne].each do |op|
      f = "IntegerType #{op} 100,200"
      parser = Parser.new
      parser.parse(f)
      assert !parser.errors?
    end
  end

  test 'fail on missing' do
    filter = "City Eq 'Fargo' And PropertyType Eq 'A'"
    filter_tokens = filter.split(' ')

    filter_tokens.each do |token|
      f = filter.gsub(token, '').gsub(/\s+/, ' ')
      parser = Parser.new
      expressions = parser.tokenize(f)
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
