require 'test_helper'

class SemanticAnalyzerTest < Test::Unit::TestCase
  test 'errors on invalid field' do
    ast = parses("Bogus Eq 'Fargo'")

    analyzer = Sparkql::SemanticAnalyzer.new({})
    analyzer.visit(ast)

    assert analyzer.errors?
  end

  test "all same types does no coercion" do
  end

  test "type coercion works for date types" do
  end

  test "type coercion works for numeric types" do
  end

=begin
  test "integer type coercion" do
    parser = Parser.new
    expression = parser.tokenize( "DecimalField Eq 100").first
    assert parser.send(:check_type!, expression, :decimal)
    assert_equal 100.0, parser.escape_value(expression)
  end
=end

=begin
  test "integer type coercion with function" do
    parser = Parser.new
    expression = parser.tokenize("fractionalseconds(SomeDate) Le 1").first
    assert parser.send(:check_type!, expression, :date)
    assert_equal 1.0, parser.escape_value(expression)
  end
=end

=begin
  test "datetime->date type coercion" do
    t = Time.now
    parser = Parser.new
    expression = parser.tokenize( "DateField Eq now()").first
    assert !parser.errors?
    assert parser.send(:check_type!, expression, :date)
    assert_equal t.strftime(Sparkql::FunctionResolver::STRFTIME_DATE_FORMAT),
                 parser.escape_value(expression).strftime(Sparkql::FunctionResolver::STRFTIME_DATE_FORMAT)
  end
=end

=begin
  test "datetime->date type coercion array" do
    today = Time.now
    parser = Parser.new
    expression = parser.tokenize('"Custom"."DateField" Bt days(-1),now()').first
    assert !parser.errors?
    assert parser.send(:check_type!, expression, :date)
    yesterday = today - 3600 * 24
    assert_equal [ yesterday.strftime(Sparkql::FunctionResolver::STRFTIME_DATE_FORMAT),
                   today.strftime(Sparkql::FunctionResolver::STRFTIME_DATE_FORMAT)],
                 parser.escape_value(expression).map { |i| i.strftime(Sparkql::FunctionResolver::STRFTIME_DATE_FORMAT)}
  end

  # TODO: move to semantic analyzer
  test "invalid regex" do
    filter = "ParcelNumber Eq regex('[1234', '')"
    @parser = Parser.new
    @parser.parse(filter)
    assert @parser.errors?, "Parser error expected due to invalid regex"
  end

  # TODO: move to semantic analyzer
  test 'invalid regex flags' do
    filter = "ParcelNumber Eq regex('^[0-9]{3}-[0-9]{2}-[0-9]{3}$', 'k')"
    @parser.parse(filter)
    assert @parser.errors?, "Parser error expected due to invalid regex flags"
  end

  test 'radius bad params'
    # TODO move radius test to semantic analysis
    parser_errors("Test Eq radius('46.8 -96.8',-20.0)")
  end

  # TODO move to semantic analyzer
  test "function radius error on invalid syntax" do
    filter = "Location Eq radius('35.12,-68.33',1.0)"
    @parser.parse(filter)
    assert @parser.errors?, "Parser error expected due to comma between radius points"
  end

    TODO: Need to do this when validating with metadata (need field types as well)
    def test_invalid_operators
      (Sparkql::Token::OPERATORS - Sparkql::Token::EQUALITY_OPERATORS).each do |o|
        ["NULL", "true", "'My String'"].each do |v|
          parser_errors("Test #{o} #{v}")
        end
      end
    end

    TODO test this during semantic analysis
    test 'coercible types' do
      @parser = Parser.new
      assert_equal :datetime, @parser.coercible_types(:date, :datetime)
      assert_equal :datetime, @parser.coercible_types(:datetime, :date)
      assert_equal :decimal, @parser.coercible_types(:decimal, :integer)
      assert_equal :decimal, @parser.coercible_types(:integer, :decimal)
      # That covers the gambit, anything else should be null
      assert_nil @parser.coercible_types(:integer, :date)
    end

  test 'wkt() invalid params' do
    f = FunctionResolver.new('wkt',
                             [{:type => :character,
                               :value => "POLYGON((45.234534534))"}])
    f.validate
    f.call
    assert f.errors?
  end
=end

  test "non-coercible types in list throws errors" do
    ["Field Bt 2012-12-31,1", "Field Bt 10,2012-12-31"].each do |f|
      parser = Sparkql::Parser.new
      ast = parser.parse(f)

      analyzer = Sparkql::SemanticAnalyzer.new({'Field' => {}})
      analyzer.visit(ast)

      assert analyzer.errors?
      assert_match(/Type mismatch/, analyzer.errors.first[:message])
    end
  end

  private

  def parses(sparkql, msg="Expected sparkql to parse: ")
    parser = Sparkql::Parser.new()
    ast = parser.parse(sparkql)
    assert !parser.errors?, "#{msg}: #{sparkql}"
    ast
  end
end
