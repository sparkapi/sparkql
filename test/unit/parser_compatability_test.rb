require 'test_helper'

class ParserCompatabilityTest < Test::Unit::TestCase
  include Sparkql

  def setup
    @expression_keys = [:field, :operator, :value]
    @multiple_types = [:character,:integer]
    @bad_character_strings = ["'Fargo's Boat'", "Fargo", "''Fargo''", "'Fargo''s'",
      "'Fargo", "Fargo'", "\\'Fargo\\'"]
    @bad_multiple_character_strings = ["'Fargo's Boat'", "Fargo", "''Fargo''", "'Fargo''s'",
      "'Fargo", "Fargo'", "\\'Fargo\\'"]
    @all_bad_strings = @bad_character_strings + @bad_multiple_character_strings
    @test_filters = [
      {
        :string => "City Eq 'Fargo'",
        :type => :character,
        :operator => "Eq"
      },
      {
        :string => "City Ne 'Fargo'",
        :type => :character,
        :operator => "Not Eq"
      },
      {
        :string => "City Eq 'Fargo','Moorhead'",
        :type => :character,
        :operator => "In"
      },
      {
        :string => "City Eq 'Fargo','Moorhead','Bemidji','Duluth'",
        :type => :character,
        :operator => "In"
      },
      {
        :string => "City Ne 'Fargo','Moorhead','Bemidji','Duluth'",
        :type => :character,
        :operator => "Not In"
      },
      {
        :string => "IntegerField Eq 2001",
        :type => :integer,
        :operator => "Eq"
      },
      {
        :string => "IntegerField Eq -2001",
        :type => :integer,
        :operator => "Eq"
      },
      {
        :string => "IntegerField Eq 2001,2002",
        :type => :integer,
        :operator => "In"
      },
      {
        :string => "IntegerField Eq -2001,-2002",
        :type => :integer,
        :operator => "In"
      },
      {
        :string => "FloatField Eq 2001.120",
        :type => :decimal,
        :operator => "Eq"
      },
      {
        :string => "FloatField Eq -2001.120",
        :type => :decimal,
        :operator => "Eq"
      },
      {
        :string => "FloatField Eq 9.1E-6",
        :type => :decimal,
        :operator => "Eq"
      },
      {
        :string => "FloatField Eq -9.1E-6",
        :type => :decimal,
        :operator => "Eq"
      },
      {
        :string => "FloatField Eq 1.0E8",
        :type => :decimal,
        :operator => "Eq"
      },
      {
        :string => "FloatField Eq -2001.120,-2002.0",
        :type => :decimal,
        :operator => "In"
      },
      {
        :string => "FloatField Eq 100.1,2,3.4",
        :type => :decimal,
        :operator => "In"
      },
      {
        :string => "DateField Eq 2010-10-10",
        :type => :date,
        :operator => "Eq"
      },
      {
        :string => "TimestampField Eq 2010-10-10T10:10:30.000000",
        :type => :datetime,
        :operator => "Eq"
      },
      {
        :string => "TimestampField Lt 2010-10-10T10:10:30.000000",
        :type => :datetime,
        :operator => "Lt"
      },
      {
        :string => "TimestampField Gt 2010-10-10T10:10:30.000000",
        :type => :datetime,
        :operator => "Gt"
      },
      {
        :string => "TimestampField Ge 2010-10-10T10:10:30.000000",
        :type => :datetime,
        :operator => "Ge"
      },
      {
        :string => "TimestampField Le 2010-10-10T10:10:30.000000",
        :type => :datetime,
        :operator => "Le"
      },
      {
        :string => "BooleanField Eq true",
        :type => :boolean,
        :operator => "Eq"
      },
      {
        :string => "BooleanField Eq false",
        :type => :boolean,
        :operator => "Eq"
      }]

  end

  def compare_expression_to_tokens( expression, tokens )
    counter = 0
    @expression_keys.each do |key|
      assert_equal tokens[counter], expression[key]
      counter += 1
    end
  end

  def find_operator(string)
    ["Eq","Ne","Gt","Ge","Lt","Le"].each do |op|
      return op if string.include? " #{op} "
    end
    nil
  end


  test "tokenize fail on invalid string operator" do
    filter = "City Eq "

    @bad_character_strings.each do |string|
      f = filter + string
      parser = Parser.new
      expressions = parser.tokenize( f )
      assert_nil expressions
      assert parser.errors?
    end
  end

  test "tokenize fail on invalid operator or field" do
    filters = ["Eq Eq 'Fargo'","City City 'Fargo'", "And Eq 'Fargo'",
      "City And 'Fargo'", "city eq 'Fargo'"]
    filters.each do |f|
      parser = Parser.new
      expressions = parser.tokenize( f )
      assert_nil expressions, "filter: #{f}"
      assert parser.errors?
    end
  end

  test "report token index on error" do
    parser = Parser.new
    parser.tokenize( "MlsStatus 2eq 'Active'" )
    error = parser.errors.first

    assert_equal "2", error.token
    assert_equal 10, error.token_index
  end

  test "tokenize edge case string value" do
    good_strings = ["'Fargo\\'s Boat'", "'Fargo'", "'Fargo\\'\\'s'",
      "' Fargo '", " 'Fargo' "]

    filters = ["City Eq ","City  Eq ", "City    Eq    "]

    filters.each do |filter|
      good_strings.each do |string|
        f = filter + string
        parser = Parser.new
        ast = parser.tokenize( f )
        assert !parser.errors?
        assert_equal :eq, ast[:name]
        assert_equal :field, ast[:lhs][:name]
        assert_equal 'City', ast[:lhs][:value]
        assert_equal :literal, ast[:rhs][:name]
      end
    end
  end

=begin
  test "max out values" do
    parser = Parser.new
    to_the_max = []
    210.times do |x|
      to_the_max << x
    end
    ex = parser.tokenize("City Eq #{to_the_max.join(',')}")
    vals = ex.first[:value]
    assert_equal 200, vals.size
    assert parser.errors?
  end
=end

=begin
  test "max out expressions" do
    parser = Parser.new
    to_the_max = []
    80.times do |x|
      to_the_max << "City Eq 'Fargo'"
    end
    vals = parser.tokenize(to_the_max.join(" And "))
    assert_equal 75, vals.size
    assert parser.errors?
  end
=end

=begin
  test "max out function args" do
    parser = Parser.new
    to_the_max = []
    201.times do |x|
      to_the_max << "1"
    end
    vals = parser.tokenize("Args Eq myfunc(#{to_the_max.join(",")})")
    assert parser.errors?
    assert parser.errors.first.constraint?
  end
=end

  test "API-107 And/Or in string spiel" do
      search_strings = ['Tom And Jerry', 'Tom Or Jerry', 'And Or Eq', 'City Eq \\\'Fargo\\\'',
        ' And Eq Or ', 'Or And Not']
      search_strings.each do |s|
        parser = Parser.new
        parser.tokenize("City Eq '#{s}' And PropertyType Eq 'A'")
        assert !parser.errors?
      end
  end

  test "general paren test" do
    [
      "(City Eq 'Fargo')",
      "(City Eq 'Fargo') And PropertyType Eq 'A'",
      "(City Eq 'Fargo') And (City Eq 'Moorhead')"
    ].each do |filter|
      parser = Parser.new
      parser.tokenize(filter)
      assert !parser.errors?
    end
  end

  test "general nesting fail test" do
    [
      "((City Eq 'Fargo')",
      "((City Eq 'Fargo') And PropertyType Eq 'A'",
      "(City Eq 'Fargo')) And (City Eq 'Moorhead')",
      "City Eq 'Fargo')",
      "(City Eq 'Fargo') And PropertyType Eq 'A')",
      "City Eq 'Fargo' (And) City Eq 'Moorhead'"
    ].each do |filter|
      parser = Parser.new
      parser.tokenize(filter)
      assert parser.errors?
    end
  end

  test "tokenize custom field with special characters" do
    filter = '"Security"."@R080T$\' ` ` `#" Eq \'R2D2\''
    parser = Parser.new
    ast = parser.tokenize( filter )
    assert !parser.errors?, "Parser errrors [#{filter}]: #{parser.errors.inspect}"
    assert_equal :custom_field, ast[:lhs][:name]
    assert_equal "\"Security\".\"@R080T$' ` ` `#\"", ast[:lhs][:value]
  end

  test "custom field supports all types" do
    types = {
      :character => "'character'",
      :integer => '1234',
      :decimal => '12.34',
      :boolean => 'true'
    }
    types.each_pair do |type, value|
      filter = '"Details"."Random" Eq ' + "#{value}"
      parser = Parser.new
      ast = parser.tokenize( filter )
      assert !parser.errors?, "Parser errrors [#{filter}]: #{parser.errors.inspect}"

      assert_equal :custom_field, ast[:lhs][:name]
      assert_equal :literal, ast[:rhs][:name]
      assert_equal type, ast[:rhs][:type]
    end
  end

  test "escape boolean value" do
    parser = Parser.new
    ast = parser.tokenize("BooleanField Eq true")
    assert_equal true, ast[:rhs][:value]
  end

  test "escape decimal values" do
    parser = Parser.new
    ast = parser.tokenize( "DecimalField Eq 0.00005 And DecimalField Eq 5.0E-5" )
    assert_equal 5.0E-5, ast[:rhs][:rhs][:value]
    assert_equal ast[:lhs][:rhs][:value], ast[:rhs][:rhs][:value]
  end

  test "Between" do
    ["BathsFull Bt 10,20", "DateField Bt 2012-12-31,2013-01-31"].each do |f|
      parser = Parser.new
      parser.tokenize f
      assert !parser.errors?, "should successfully parse proper between values, but #{parser.errors.first}"
    end

    # Parser does not handle invalid types
    ["BathsFull Bt 2012-12-31,1", "DateField Bt 10,2012-12-31"].each do |f|
      parser = Parser.new
      parser.tokenize f
      assert !parser.errors?, "should not error parsing with invalid types: #{parser.errors.first}"
      #assert_match(/Type mismatch/, parser.errors.first.message)
    end

  end


end
