require 'test_helper'

# Security regression tests covering SQL injection attack vectors identified
# during audit. The parser is responsible for rejecting malformed input and
# producing type-safe output. Consumers of parser output must still use
# parameterized queries and quote field identifiers — see comments below.
class SecurityTest < Test::Unit::TestCase
  include Sparkql

  def setup
    @parser = Parser.new
  end

  # --- String value injection ---

  test 'rejects unclosed string literals' do
    assert_parse_error "City Eq 'Fargo"
    assert_parse_error "City Eq Fargo'"
  end

  test 'rejects double-quote SQL injection in string values' do
    # SparkQL only recognises \' as an escape sequence inside strings.
    # A bare '' does not escape the quote — the lexer matches 'test' and
    # the leftover 'injection' token causes a parse error.
    assert_parse_error "City Eq 'test''injection'"
  end

  test 'string with backslash-escaped quote parses and escapes safely' do
    # \' is the valid SparkQL escape for a literal apostrophe. :value retains
    # outer quotes; character_escape strips them and unescapes \' to '.
    # The resulting value contains a single quote — consumers MUST use bind
    # parameters, not string interpolation, when building SQL from this value.
    expressions = @parser.parse("City Eq 'O\\'Brien'")
    assert !@parser.errors?, @parser.errors.inspect
    assert_equal "O'Brien", @parser.character_escape(expressions.first[:value])
  end

  test 'sql payload inside valid sparkql string is accepted but value is raw' do
    # The lexer correctly accepts 'val\'; DROP TABLE t; --' as a character
    # literal (\' is a valid escape sequence). character_escape returns the raw
    # string including the injected SQL — safe only with parameterized queries.
    expressions = @parser.parse("City Eq 'val\\'; DROP TABLE t; --'")
    assert !@parser.errors?, @parser.errors.inspect
    assert_equal "val'; DROP TABLE t; --", @parser.character_escape(expressions.first[:value])
  end

  test 'plain string :value retains outer quotes before character_escape' do
    expressions = @parser.parse("City Eq 'Fargo'")
    assert !@parser.errors?, @parser.errors.inspect
    assert_equal "'Fargo'", expressions.first[:value]
    assert_equal :character, expressions.first[:type]
    assert_equal 'Fargo', @parser.character_escape(expressions.first[:value])
  end

  # --- Numeric/decimal injection ---

  test 'rejects sql keywords appended after integer token' do
    assert_parse_error "Price Eq 100; DROP TABLE listings"
    assert_parse_error "Price Eq 100 UNION SELECT"
  end

  test 'integer values are coerced to integers preventing non-numeric injection' do
    expressions = @parser.parse("Price Eq 100")
    assert !@parser.errors?, @parser.errors.inspect
    assert_equal '100', expressions.first[:value]
    assert_equal :integer, expressions.first[:type]
  end

  test 'decimal values are stored as strings preventing non-numeric injection' do
    expressions = @parser.parse("Price Eq 100.50")
    assert !@parser.errors?, @parser.errors.inspect
    assert_equal '100.50', expressions.first[:value]
    assert_equal :decimal, expressions.first[:type]
  end

  # --- Operator injection ---

  test 'rejects sql operators that are not in the sparkql whitelist' do
    assert_parse_error "City LIKE '%Fargo%'"
    assert_parse_error "Price > 100"
    assert_parse_error "Price < 100"
    assert_parse_error "Price != 100"
  end

  test 'rejects sql keywords used as conjunctions' do
    # OR/AND lowercased is valid SparkQL, but 1=1 is not a valid expression.
    # Uppercase SQL keywords like UNION are rejected entirely.
    assert_parse_error "City Eq 'Fargo' UNION SELECT City FROM listings"
    assert_parse_error "City Eq 'Fargo' OR 1=1"
    assert_parse_error "City Eq 'Fargo' AND 1=1"
  end

  # --- Function name injection ---

  test 'rejects function names not in the supported functions whitelist' do
    assert_parse_error "City Eq unknownfn('Fargo')"
    assert_parse_error "City Eq exec('xp_cmdshell')"
    assert_parse_error "City Eq sleep(10)"
  end

  # --- Custom field name handling ---

  test 'custom field regex rejects names starting with dollar sign or period' do
    assert_parse_error '"$BadGroup"."Field" Eq 10'
    assert_parse_error '"Group"."$BadField" Eq 10'
    assert_parse_error '"Group".".BadField" Eq 10'
    assert_parse_error '"Group.Bad"."Field" Eq 10'
    assert_parse_error '"Group"."Field.Sub" Eq 10'
    assert_parse_error '""."" Eq 10'
  end

  test 'valid custom field names parse and field is returned verbatim' do
    filter = '"General Property Description"."Taxes" Lt 500.0'
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect
    assert expressions.first[:custom_field]
    # The field value is returned as-is with its surrounding double-quotes.
    # Consumers MUST validate this against allowed metadata and/or quote it
    # as a SQL identifier before using it in a query — never interpolate directly.
    assert_equal '"General Property Description"."Taxes"', expressions.first[:field]
  end

  test 'custom field name containing sql-significant characters is returned verbatim' do
    # SparkQL allows characters like ; and ' inside double-quoted field names.
    # The CUSTOM_FIELD regex does not strip these — that is the consumer's job.
    filter = %("It's a field"."Value" Eq 10)
    expressions = @parser.parse(filter)
    assert !@parser.errors?, @parser.errors.inspect
    assert expressions.first[:custom_field]
    assert expressions.first[:field].include?("It's a field"), \
      "Expected field to contain the group name, got: #{expressions.first[:field].inspect}"
  end

  # --- Date/datetime injection ---

  test 'valid dates parse to their string representation' do
    expressions = @parser.parse("DateField Eq 2023-06-15")
    assert !@parser.errors?, @parser.errors.inspect
    assert_equal '2023-06-15', expressions.first[:value]
    assert_equal :date, expressions.first[:type]
  end

  private

  def assert_parse_error(filter)
    parser = Parser.new
    parser.parse(filter)
    assert parser.errors?, "Expected parse error for: #{filter.inspect}"
  end
end
