require 'test_helper'

class SemanticAnalyzerTest < Test::Unit::TestCase
  def setup
    @fields = {
      'StringField' => {
        searchable: true,
        type: :character
      },
      'NoSearchStringField' => {
        searchable: false,
        type: :character
      },
      'IntField' => {
        searchable: true,
        type: :integer
      },
      'DateField' => {
        searchable: true,
        type: :date
      },
      '"Custom"."DateField"' => {
        searchable: true,
        type: :date
      },
      'DecimalField' => {
        searchable: true,
        type: :decimal
      },
      'Location' => {
        searchable: true,
        type: :shape
      }
    }
  end

  STRING_OPERATORS = %w[Eq Ne].freeze
  NUMBER_OPERATORS = %w[Eq Ne Gt Ge Lt Le].freeze

  test 'errors on invalid field' do
    assert_errors("Bogus Eq 'Fargo'")
  end

  test 'In' do
    assert_errors "StringField Eq 1,'2'"
    assert_success "StringField Eq '1','2'"
    assert_success 'IntField Eq 1,2.0'
  end

  test 'toupper fails without 1 character parameter' do
    STRING_OPERATORS.each do |op|
      assert_errors("StringField #{op} toupper()")
      assert_errors("StringField #{op} toupper('First', 'Second')")
      assert_errors("StringField #{op} toupper(1)")
      assert_errors("StringField #{op} toupper(IntField)")
      assert_success("StringField #{op} toupper(StringField)")
      assert_success("StringField #{op} toupper('Far')")
    end
  end

  test 'tolower fails without 1 character parameter' do
    STRING_OPERATORS.each do |op|
      assert_errors("StringField #{op} tolower()")
      assert_errors("StringField #{op} tolower('First', 'Second')")
      assert_errors("StringField #{op} tolower(1)")
      assert_errors("StringField #{op} tolower(IntField)")
      assert_success("StringField #{op} tolower(StringField)")
      assert_success("StringField #{op} tolower('Far')")
    end
  end

  test 'length fails without bad parameters' do
    NUMBER_OPERATORS.each do |op|
      assert_errors("IntField #{op} length()")
      assert_errors("IntField #{op} length('First', 'Second')")
      assert_errors("IntField #{op} length(1)")
      assert_errors("IntField #{op} length(IntField)")
      assert_success("IntField #{op} length('a')")
      assert_success("IntField #{op} length(StringField)")
    end
  end

  test 'now requires no parameters' do
    NUMBER_OPERATORS.each do |op|
      assert_errors("DateField #{op} now(1)")
      assert_errors("DateField #{op} now('1')")
      assert_success("DateField #{op} now()")
    end
  end

  test 'mindatetime requires no parameters' do
    NUMBER_OPERATORS.each do |op|
      assert_errors("DateField #{op} mindatetime(1)")
      assert_errors("DateField #{op} mindatetime('1')")
      assert_success("DateField #{op} mindatetime()")
    end
  end

  test 'maxdatetime requires no parameters' do
    NUMBER_OPERATORS.each do |op|
      assert_errors("DateField #{op} maxdatetime(1)")
      assert_errors("DateField #{op} maxdatetime('1')")
      assert_success("DateField #{op} maxdatetime()")
    end
  end

  test 'integer type coercion' do
    parse_tree = assert_success('DecimalField Eq 100')
    assert_equal :coerce, parse_tree[:rhs][:name]
    assert_equal :integer, parse_tree[:rhs][:lhs][:type]
    assert_equal :decimal, parse_tree[:rhs][:rhs]
  end

  test 'integer type coercion with function' do
    parse_tree = assert_success('fractionalseconds(DateField) Le 1')
    assert_equal :le, parse_tree[:name]
    assert_equal :coerce, parse_tree[:rhs][:name]
    assert_equal :decimal, parse_tree[:rhs][:rhs]
    assert_equal :fractionalseconds, parse_tree[:lhs][:name]
  end

  test 'datetime->date type coercion' do
    parse_tree = assert_success('DateField Eq now()')
    assert_equal :eq, parse_tree[:name]
    assert_equal :coerce, parse_tree[:lhs][:name]
    assert_equal :datetime, parse_tree[:lhs][:rhs]
    assert_equal :now, parse_tree[:rhs][:name]
  end

  test 'datetime->date type coercion array' do
    parse_tree = assert_success('"Custom"."DateField" Bt days(-1),now()')
    assert_equal :coerce, parse_tree[:lhs][:name]
    assert_equal :datetime, parse_tree[:lhs][:rhs]
    assert_equal :days, parse_tree[:rhs].first[:name]
    assert_equal :now, parse_tree[:rhs].last[:name]
  end

  test 'inalid regex' do
    assert_errors("StringField Eq regex('[1234', '')")
  end

  test 'inalid regex flags' do
    assert_errors("StringField Eq regex('^[0-9]{3}-[0-9]{2}-[0-9]{3}$', 'k')")
  end

  test 'radius bad params' do
    assert_errors("Location Eq radius('46.8 -96.8',-20.0)")
  end

  test 'function radius error on invalid syntax' do
    assert_errors("Location Eq radius('35.12,-68.33',1.0)")
  end

  test 'radius allows tech_id' do
    assert_success("Location Eq radius('20100000000000000000000000',1)")
  end

  test 'invalid operators' do
    (Sparkql::Token::OPERATORS - Sparkql::Token::EQUALITY_OPERATORS).each do |o|
      ['NULL', 'true', "'My String'"].each do |v|
        assert_errors("StringField #{o} #{v}").inspect
      end
    end
  end

  test 'wkt() invalid params' do
    assert_errors("Location Eq wkt('POLYGON((45.234534534))')")
  end

  test 'non-coercible types in list throws errors' do
    ['Field Bt 2012-12-31,1', 'Field Bt 10,2012-12-31'].each do |f|
      parser = Sparkql::Parser.new
      ast = parser.parse(f)

      analyzer = Sparkql::SemanticAnalyzer.new('Field' => {})
      analyzer.visit(ast)

      assert analyzer.errors?
      assert_match(/Type mismatch/, analyzer.errors.first[:message])
    end
  end

  test 'No extra function validations break on invalid field types within parameters' do
    assert_nothing_raised do
      assert_errors("Location Eq radius('46.8 -96.8','-20.0')")
    end
  end

  private

  def parses(sparkql, msg = 'Expected sparkql to parse: ')
    parser = Sparkql::Parser.new
    ast = parser.parse(sparkql)
    assert !parser.errors?, "#{msg}: #{sparkql}"
    ast
  end

  def assert_errors(sparkql)
    ast = parses(sparkql)
    analyzer = Sparkql::SemanticAnalyzer.new(@fields)
    analyzer.visit(ast)
    assert(analyzer.errors?, sparkql.inspect)
    analyzer.errors
  end

  def assert_success(sparkql)
    ast = parses(sparkql)
    analyzer = Sparkql::SemanticAnalyzer.new(@fields)
    parse_tree = analyzer.visit(ast)
    assert(!analyzer.errors?, "sparkql: #{sparkql}, #{analyzer.errors.inspect}")
    parse_tree
  end
end
