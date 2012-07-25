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
        :string => "FloatField Eq -2001.120,-2002.0",
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

  test "simple tokenize" do
    filter = "City Eq 'Fargo'"
    filter_tokens = filter.split(" ")
    parser = Parser.new
    expressions = parser.tokenize( filter )

    assert !parser.errors?
    assert_equal 1, expressions.size, "#Expressions {expressions.inspect}"
    compare_expression_to_tokens(expressions.first, filter_tokens)
  end
 
  test "types" do
    @test_filters.each do |elem|
      parser = Parser.new
      expressions = parser.tokenize( elem[:string] )

      assert !parser.errors?, "Query: #{elem.inspect}"
      assert_equal elem[:type], expressions.first[:type]
    end
  end

  test "operators" do
    @test_filters.each do |elem|
      parser = Parser.new
      expressions = parser.tokenize( elem[:string] )
      assert !parser.errors?, "Query: #{elem.inspect}"
      assert_equal elem[:operator], expressions.first[:operator]
    end
  end

  test "tokenize with and" do
    filter = "City Eq 'Fargo' And PropertyType Eq 'A'"
    filter_a = filter.split(" And ")
    filter_tokens = []
    filter_a.each do |f|
      filter_tokens << f.split(" ")
    end
    parser = Parser.new
    expressions = parser.tokenize( filter )

    assert !parser.errors?
    assert_equal 2, expressions.size

    counter = 0
    filter_tokens.each do |t|
      compare_expression_to_tokens(expressions[counter], t)
      counter += 1
    end
  end

  test "tokenize with or" do
    filter = "City Eq 'Fargo' Or PropertyType Eq 'A'"
    filter_a = filter.split(" Or ")
    filter_tokens = []
    filter_a.each do |f|
      filter_tokens << f.split(" ")
    end
    parser = Parser.new
    expressions = parser.tokenize( filter )

    assert !parser.errors?
    assert_equal 2, expressions.size

    counter = 0
    filter_tokens.each do |t|
      compare_expression_to_tokens(expressions[counter], t)
      counter += 1
    end
  end

  test "tokenize fail on missing" do
    # We want to cut out each piece of this individually, and make sure
    # tokenization fails
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

  test "tokenize edge case string value" do
    good_strings = ["'Fargo\\'s Boat'", "'Fargo'", "'Fargo\\'\\'s'",
      "' Fargo '", " 'Fargo' "]

    filters = ["City Eq ","City  Eq ", "City    Eq    "]

    filters.each do |filter|
      good_strings.each do |string|
        f = filter + string
        parser = Parser.new
        expressions = parser.tokenize( f )
        assert !parser.errors?
        assert_equal 1, expressions.size
        assert_equal string.strip, expressions.first[:value]
      end
    end
  end
  
  test "get multiple values" do
    @test_filters.each do |f|
      op = find_operator f[:string] 
      next unless @multiple_types.include?(f[:type]) || op.nil? 
      parser = Parser.new
      val = f[:string].split(" #{op} ")[1]
      vals = parser.tokenize(f[:string]).first[:value]
      assert_equal val, Array(vals).join(',')
    end
  end

  test "multiples fail with unsupported operators" do
    ["Gt","Ge","Lt","Le"].each do |op|
      f = "IntegerType #{op} 100,200" 
      parser = Parser.new
      expressions = parser.tokenize( f )
      assert parser.errors?
      assert_equal op, parser.errors.first.token
    end 
  end

  test "bad multiples" do
    @all_bad_strings.each do |bad|
      parser = Parser.new
      ex = parser.tokenize("City Eq #{bad}")
      assert parser.errors?
      assert_nil ex
    end
  end

  test "max out values" do
      parser = Parser.new
      to_the_max = []
      35.times do |x|
        to_the_max << x
      end
      ex = parser.tokenize("City Eq #{to_the_max.join(',')}")
      vals = ex.first[:value]
      assert_equal 25, vals.size
  end

  test "max out expressions" do
      parser = Parser.new
      to_the_max = []
      60.times do |x|
        to_the_max << "City Eq 'Fargo'"
      end
      vals = parser.tokenize(to_the_max.join(" And "))
      assert_equal 50, vals.size
  end

  test "API-107 And/Or in string spiel" do
      search_strings = ['Tom And Jerry', 'Tom Or Jerry', 'And Or Eq', 'City Eq \\\'Fargo\\\'',
        ' And Eq Or ', 'Or And Or']
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
      p = parser.tokenize(filter)
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
      p = parser.tokenize(filter)
      assert parser.errors?
    end
  end

  test "block group" do
    parser = Parser.new
    p = parser.tokenize("(City Eq 'Fargo' Or TotalBr Eq 2) And (City Eq 'Moorhead')")
    assert !parser.errors?
    assert p.first[:block_group] == p[1][:block_group]
    assert p.first[:block_group] == p[2][:block_group] - 1
  end

  test "proper nesting" do
    parser = Parser.new
    p = parser.tokenize("(City Eq 'Fargo' Or TotalBr Eq 2) And PropertyType Eq 'A'")
    assert !parser.errors?
    p.each do |token|
      if ["City","TotalBr"].include?(token[:field])
        assert_equal 1, token[:level], "Token: #{token.inspect}"
      else
        assert_equal 0, token[:level]
      end
    end

    parser = Parser.new
    p = parser.tokenize("(City Eq 'Fargo' Or TotalBr Eq 2 Or City Eq 'Moorhead') " +
                        "And PropertyType Eq 'A' And (TotalBr Eq 1 And TotalBr Eq 2)")
    assert !parser.errors?
    p.each do |token|
      if ["City","TotalBr"].include?(token[:field])
        assert_equal 1, token[:level]
      else
        assert_equal 0, token[:level]
      end
    end
  end

  test "maximum nesting of 2" do
    parser = Parser.new
    p = parser.tokenize("(City Eq 'Fargo' Or (TotalBr Eq 2 And (City Eq 'Moorhead'))) And PropertyType Eq 'A'")
    assert parser.errors?
    assert_equal "You have exceeded the maximum nesting level.  Please nest no more than 2 levels deep.", parser.errors.first.message
  end

  test "tokenize custom field" do
    filter = '"General Property Description"."Zoning" Eq \'Commercial\''
    filter_tokens = ['"General Property Description"."Zoning"', 'Eq', "'Commercial'"]
    parser = Parser.new
    expressions = parser.tokenize( filter )
    
    assert !parser.errors?, "Parser errrors [#{filter}]: #{parser.errors.inspect}"
    assert_equal 1, expressions.size, "Expression #{expressions.inspect}"
    compare_expression_to_tokens(expressions.first, filter_tokens)
    assert expressions.first[:custom_field], "Expression #{expressions.first.inspect}"
  end
  
  test "tokenize custom field with special characters" do
    filter = '"Security"."@R080T$\' ` ` `#" Eq \'R2D2\''
    filter_tokens = ['"Security"."@R080T$\' ` ` `#"', 'Eq', "'R2D2'"]
    parser = Parser.new
    expressions = parser.tokenize( filter )
    assert !parser.errors?, "Parser errrors [#{filter}]: #{parser.errors.inspect}"
    assert_equal 1, expressions.size, "Expression #{expressions.inspect}"
    compare_expression_to_tokens(expressions.first, filter_tokens)
    assert expressions.first[:custom_field], "Expression #{expressions.first.inspect}"
  end
  
  test "custom field supports all types" do
    types = {
      :character => "'character'",
      :integer => 1234,
      :decimal => 12.34,
      :boolean => true
    }
    types.each_pair do |key, value|
      filter = '"Details"."Random" Eq ' + "#{value}"
      filter_tokens = ['"Details"."Random"', 'Eq', "#{value}"]
      parser = Parser.new
      expressions = parser.tokenize( filter )
      
      assert !parser.errors?, "Parser errrors [#{filter}]: #{parser.errors.inspect}"
      assert_equal 1, expressions.size, "Expression #{expressions.inspect}"
      compare_expression_to_tokens(expressions.first, filter_tokens)
      assert expressions.first[:custom_field], "Expression #{expressions.first.inspect}"
    end
  end
  
end
