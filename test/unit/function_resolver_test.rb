require 'test_helper'
require 'sparkql/geo'

class FunctionResolverTest < Test::Unit::TestCase
  include Sparkql
  
  EXAMPLE_DATE = DateTime.parse("2013-07-26T10:22:15.422804")

  test "function parameters and name preserved" do
    f = FunctionResolver.new('radius', [{:type => :character, 
          :value => "35.12 -68.33"},{:type => :decimal, :value => 1.0}])
    value = f.call
    assert_equal 'radius', value[:function_name]
    assert_equal(["35.12 -68.33", 1.0], value[:function_parameters])
  end

  test "round(float)" do
    f = FunctionResolver.new('round', [{:type => :decimal, :value => 0.5}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :integer, value[:type]
    assert_equal '1', value[:value]
  end

  test "round(Field)" do
    f = FunctionResolver.new('round', [{:type => :field, :value => 'ListPrice'}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :function, value[:type]
    assert_equal 'round', value[:value]
    assert_equal "ListPrice", value[:args].first[:value]
  end

  test "substring character one index" do
    f = FunctionResolver.new('substring', [
      {:type => :character, :value => 'ListPrice'},
      {:type => :integer, :value => 1}
    ])

    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :character, value[:type]
    assert_equal 'istPrice', value[:value]
  end

  test "substring character two indexes" do
    f = FunctionResolver.new('substring', [
      {:type => :character, :value => 'alfb'},
      {:type => :integer, :value => 1},
      {:type => :integer, :value => 2}
    ])

    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :character, value[:type]
    assert_equal "lf", value[:value]
  end

  test "substring character large first index" do
    f = FunctionResolver.new('substring', [
      {:type => :character, :value => 'ListPrice'},
      {:type => :integer, :value => 10}
    ])

    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :character, value[:type]
    assert_equal '', value[:value]
  end

  test "substring field one index" do
    f = FunctionResolver.new('substring', [
      {:type => :field, :value => 'ListPrice'},
      {:type => :integer, :value => 1}
    ])

    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :function, value[:type]
    assert_equal 'substring', value[:value]
    assert_equal "ListPrice", value[:args].first[:value]
    assert_equal 2, value[:args].size
  end

  test "substring field two indexes" do
    f = FunctionResolver.new('substring', [
      {:type => :field, :value => 'ListPrice'},
      {:type => :integer, :value => 1},
      {:type => :integer, :value => 2}
    ])

    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :function, value[:type]
    assert_equal 'substring', value[:value]
    assert_equal "ListPrice", value[:args].first[:value]
    assert_equal 2, value[:args].last[:value]
  end

  test "substring with negative M is a parse error" do
    f = FunctionResolver.new('substring', [
      {:type => :field, :value => 'ListPrice'},
      {:type => :integer, :value => 1},
      {:type => :integer, :value => -5}
    ])

    f.validate
    f.call
    assert f.errors?
  end

  test "character substring with negative M is a parse error" do
    f = FunctionResolver.new('substring', [
      {:type => :character, :value => 'ListPrice'},
      {:type => :integer, :value => 1},
      {:type => :integer, :value => -5}
    ])

    f.validate
    f.call
    assert f.errors?
  end

  test 'trim with field' do
    f = FunctionResolver.new('trim', [
      {:type => :field, :value => 'Name'}
    ])

    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :function, value[:type]
    assert_equal 'trim', value[:value]
    assert_equal "Name", value[:args].first[:value]
  end

  test 'trim with character' do
    f = FunctionResolver.new('trim', [
      {:type => :character, :value => ' val '}
    ])

    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :character, value[:type]
    assert_equal 'val', value[:value]
  end

  test "tolower('string')" do
    f = FunctionResolver.new('tolower', [{:type => :character, :value => "STRING"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :character, value[:type]
    assert_equal "'string'", value[:value]
  end

  test "toupper(SomeField)" do
    f = FunctionResolver.new('toupper', [{:type => :field, :value => "City"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :function, value[:type]
    assert_equal 'toupper', value[:value]
    assert_equal "City", value[:args].first[:value]
  end

  test "toupper('string')" do
    f = FunctionResolver.new('toupper', [{:type => :character, :value => "string"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :character, value[:type]
    assert_equal "'STRING'", value[:value]
  end

  test "length(SomeField)" do
    f = FunctionResolver.new('length', [{:type => :field, :value => "City"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :function, value[:type]
    assert_equal 'length', value[:value]
    assert_equal "City", value[:args].first[:value]
  end

  test "length('string')" do
    f = FunctionResolver.new('length', [{:type => :character, :value => "string"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :integer, value[:type]
    assert_equal '6', value[:value]
  end

  test "now()" do
    start = Time.now
    f = FunctionResolver.new('now', [])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :datetime, value[:type]
    test_time = Time.parse(value[:value])
    assert (-5 < test_time - start && 5 > test_time - start), "Time range off by more than five seconds #{test_time - start} '#{test_time} - #{start}'"
  end

  test "mindatetime()" do
    f = FunctionResolver.new('mindatetime', [])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :datetime, value[:type]

    assert_equal '1970-01-01T00:00:00+00:00', value[:value]
  end

  test "maxdatetime()" do
    f = FunctionResolver.new('maxdatetime', [])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :datetime, value[:type]

    assert_equal '9999-12-31T23:59:59+00:00', value[:value]
  end

  test "floor(float)" do
    f = FunctionResolver.new('floor', [{:type => :decimal, :value => 0.5}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :integer, value[:type]
    assert_equal '0', value[:value]
  end

  test "floor(Field)" do
    f = FunctionResolver.new('floor', [{:type => :field, :value => 'ListPrice'}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :function, value[:type]
    assert_equal 'floor', value[:value]
    assert_equal "ListPrice", value[:args].first[:value]
  end

  test "ceiling(float)" do
    f = FunctionResolver.new('ceiling', [{:type => :decimal, :value => 0.5}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :integer, value[:type]
    assert_equal '1', value[:value]
  end

  test "ceiling(Field)" do
    f = FunctionResolver.new('ceiling', [{:type => :field, :value => 'ListPrice'}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :function, value[:type]
    assert_equal 'ceiling', value[:value]
    assert_equal "ListPrice", value[:args].first[:value]
  end

  test "seconds()" do
    dt = Time.new(2019, 4, 1, 8, 30, 20, 0)

    Time.expects(:now).returns(dt).times(3)

    f = FunctionResolver.new('seconds', [{:type=>:integer, :value => 7}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    
    assert_equal :datetime, value[:type]
    d = DateTime.parse(value[:value])
    assert_equal dt.year, d.year
    assert_equal dt.month, d.month
    assert_equal dt.mday, d.mday
    assert_equal dt.hour, d.hour
    assert_equal dt.min, d.min
    assert_equal dt.sec + 7, d.sec

    f = FunctionResolver.new('seconds', [{:type=>:integer, :value => -21}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    
    assert_equal :datetime, value[:type]
    d = DateTime.parse(value[:value])
    assert_equal dt.year, d.year
    assert_equal dt.month, d.month
    assert_equal dt.mday, d.mday
    assert_equal dt.hour, d.hour
    assert_equal dt.min - 1, d.min
    assert_equal 29, d.min
    assert_equal 59, d.sec

    f = FunctionResolver.new('seconds', [{:type=>:integer, 
                                          :value => -Sparkql::FunctionResolver::SECONDS_IN_DAY}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    
    assert_equal :datetime, value[:type]
    d = DateTime.parse(value[:value])
    assert_equal dt.year, d.year
    assert_equal dt.month - 1, d.month
    assert_equal 31, d.mday
    assert_equal dt.hour, d.hour
    assert_equal dt.min, d.min
    assert_equal dt.min, d.min
    assert_equal dt.sec, d.sec
  end

  test "minutes()" do
    dt =Time.new(2019, 4, 1, 8, 30, 20, 0)

    Time.expects(:now).returns(dt).times(3)

    f = FunctionResolver.new('minutes', [{:type=>:integer, :value => 7}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    
    assert_equal :datetime, value[:type]
    d = DateTime.parse(value[:value])
    assert_equal dt.year, d.year
    assert_equal dt.month, d.month
    assert_equal dt.mday, d.mday
    assert_equal dt.hour, d.hour
    assert_equal dt.min + 7, d.min
    assert_equal dt.sec, d.sec

    f = FunctionResolver.new('minutes', [{:type=>:integer, :value => -37}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    
    assert_equal :datetime, value[:type]
    d = DateTime.parse(value[:value])
    assert_equal dt.year, d.year
    assert_equal dt.month, d.month
    assert_equal dt.mday, d.mday
    assert_equal dt.hour-1, d.hour
    assert_equal 53, d.min

    f = FunctionResolver.new('minutes', [{:type=>:integer, 
                                          :value => -1440}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    
    assert_equal :datetime, value[:type]
    d = DateTime.parse(value[:value])
    assert_equal dt.year, d.year
    assert_equal dt.month - 1, d.month
    assert_equal 31, d.mday
    assert_equal dt.hour, d.hour
    assert_equal dt.min, d.min
  end

  test "hours(), same day" do
    dt =Time.new(2019, 4, 1, 8, 30, 20, 0)

    tests = [1, -1, 5, -5, 12]
    Time.expects(:now).returns(dt).times(tests.count)

    tests.each do |offset|
      f = FunctionResolver.new('hours', [{:type=>:integer, 
                                          :value => offset}])
      f.validate
      assert !f.errors?, "Errors #{f.errors.inspect}"
      value = f.call
      
      assert_equal :datetime, value[:type]
      d = DateTime.parse(value[:value])
      assert_equal dt.year, d.year
      assert_equal dt.month, d.month
      assert_equal dt.mday, d.mday
      assert_equal dt.hour + offset, d.hour
      assert_equal dt.min, d.min
      assert_equal dt.sec, d.sec
    end
  end

  test "hours(), wrap day" do
    dt =Time.new(2019, 4, 1, 8, 30, 20, 0)
    Time.expects(:now).returns(dt).times(3)

    # Jump forward a few days, and a few hours.
    f = FunctionResolver.new('hours', [{:type=>:integer, :value => 52}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    
    assert_equal :datetime, value[:type]
    d = DateTime.parse(value[:value])
    assert_equal dt.year, d.year
    assert_equal dt.month, d.month
    assert_equal dt.mday + 2, d.mday
    assert_equal dt.hour + 4, d.hour
    assert_equal dt.min, d.min

    # Drop back to the previous day, which'll also hit the previous month
    f = FunctionResolver.new('hours', [{:type=>:integer, :value => -24}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    
    assert_equal :datetime, value[:type]
    d = DateTime.parse(value[:value])
    assert_equal dt.year, d.year
    assert_equal dt.month - 1, d.month
    assert_equal 31, d.mday
    assert_equal dt.hour, d.hour
    assert_equal dt.min, d.min

    # Drop back one full year's worth of hours.
    f = FunctionResolver.new('hours', [{:type=>:integer, :value => -8760}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    
    assert_equal :datetime, value[:type]
    d = DateTime.parse(value[:value])
    assert_equal dt.year - 1, d.year
    assert_equal dt.month, d.month
    assert_equal dt.mday, d.mday
    assert_equal dt.hour, d.hour
    assert_equal dt.min, d.min
  end

  test "days()" do
    d = Date.new(2012,10,20)
    Date.expects(:today).returns(d)
    dt = DateTime.new(d.year, d.month,d.day, 0,0,0, DateTime.now.offset)
    start = Time.parse(dt.to_s)
    f = FunctionResolver.new('days', [{:type=>:integer, :value =>7}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :date, value[:type]
    test_time = Time.parse(value[:value])
    assert (615000 > test_time - start && 600000 < test_time - start), "Time range off by more than five seconds #{test_time - start} '#{test_time} - #{start}'"
  end

  test "months()" do
    dt = DateTime.new(2014, 1, 6, 0, 0, 0, 0)
    DateTime.expects(:now).once.returns(dt)

    f = FunctionResolver.new('months', [{:type=>:integer, :value =>3}])
    f.validate
    assert !f.errors?, "Errors resolving months(): #{f.errors.inspect}"
    value = f.call
    assert_equal :date, value[:type]

    assert_equal "2014-04-06", value[:value]
  end
  
  test "years()" do
    dt = DateTime.new(2014, 1, 6, 0, 0, 0, 0)
    DateTime.expects(:now).once.returns(dt)
    f = FunctionResolver.new('years', [{:type=>:integer, :value =>-4}])
    f.validate
    assert !f.errors?, "Errors resolving years(): #{f.errors.inspect}"
    value = f.call
    assert_equal :date, value[:type]
    assert_equal '2010-01-06', value[:value], "negative values should go back in time"
  end

  test "year(), month(), and day()" do
    ['year', 'month', 'day'].each do |function|
      f = FunctionResolver.new(function, [{:type => :field, :value => "OriginalEntryTimestamp"}])
      f.validate
      assert !f.errors?, "Errors #{f.errors.inspect}"
      value = f.call
      assert_equal :function, value[:type]
      assert_equal function, value[:value]
      assert_equal "OriginalEntryTimestamp", value[:args].first[:value]
    end
  end

  test "hour(), minute(), and second()" do
    ['year', 'month', 'day'].each do |function|
      f = FunctionResolver.new(function, [{:type => :field, :value => "OriginalEntryTimestamp"}])
      f.validate
      assert !f.errors?, "Errors #{f.errors.inspect}"
      value = f.call
      assert_equal :function, value[:type]
      assert_equal function, value[:value]
      assert_equal "OriginalEntryTimestamp", value[:args].first[:value]
    end
  end

  test "fractionalseconds()" do
    f = FunctionResolver.new('fractionalseconds', [{:type => :field, :value => "OriginalEntryTimestamp"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :function, value[:type]
    assert_equal 'fractionalseconds', value[:value]
    assert_equal "OriginalEntryTimestamp", value[:args].first[:value]
  end

  # Polygon searches
  
  test "radius()" do
    f = FunctionResolver.new('radius', [{:type => :character, :value => "35.12 -68.33"},{:type => :decimal, :value => 1.0}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :shape, value[:type]
    assert_equal GeoRuby::SimpleFeatures::Circle, value[:value].class
    assert_equal [-68.33, 35.12], value[:value].center.to_coordinates, "#{value[:value].inspect} "
    assert_equal 1.0, value[:value].radius, "#{value[:value].inspect} "
  end

  test "radius() can be overloaded with a ListingKey" do
    f = FunctionResolver.new('radius', [{:type => :character, :value => "20100000000000000000000000"},
                {:type => :decimal, :value => 1.0}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :shape, value[:type]
    assert_equal Sparkql::Geo::RecordRadius, value[:value].class
    assert_equal "20100000000000000000000000", value[:value].record_id, "#{value[:value].inspect} "
    assert_equal 1.0, value[:value].radius, "#{value[:value].inspect} "
  end

  test "radius() fails if not given coords or a flex ID" do
    f = FunctionResolver.new('radius', [{:type => :character, :value => "35.12,-68.33"},
                {:type => :decimal, :value => 1.0}])
    f.validate
    f.call
    assert f.errors?
  end

  test "polygon()" do
    f = FunctionResolver.new('polygon', [{:type => :character, :value => "35.12 -68.33,35.12 -68.32, 35.13 -68.32,35.13 -68.33"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :shape, value[:type]
    assert_equal GeoRuby::SimpleFeatures::Polygon, value[:value].class
    assert_equal [[-68.33, 35.12], [-68.32, 35.12], [-68.32, 35.13], [-68.33, 35.13], [-68.33, 35.12]], value[:value].to_coordinates.first, "#{value[:value].inspect} "
  end
 
  test "linestring()" do
    f = FunctionResolver.new('linestring', [{:type => :character, :value => "35.12 -68.33,35.12 -68.32"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :shape, value[:type]
    assert_equal GeoRuby::SimpleFeatures::LineString, value[:value].class
    assert_equal [[-68.33, 35.12], [-68.32, 35.12]], value[:value].to_coordinates, "#{value[:value].inspect} "
  end

  test "rectangle()" do
    f = FunctionResolver.new('rectangle', [{:type => :character, :value => "35.12 -68.33, 35.13 -68.32"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :shape, value[:type]
    assert_equal GeoRuby::SimpleFeatures::Polygon, value[:value].class
    assert_equal [[-68.33,35.12], [-68.32,35.12], [-68.32,35.13], [-68.33,35.13], [-68.33,35.12]], value[:value].to_coordinates.first, "#{value[:value].inspect} "
  end

  test "range()" do
    f = FunctionResolver.new('range', [{:type => :character, :value => "M01"},
                                              {:type => :character, :value => "M05"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :character, value[:type]
    assert_equal ["M01", "M05"], value[:value]
  end
  
  test "invalid params" do
    f = FunctionResolver.new('now', [{:type => :character, :value=>'bad value'}])
    f.validate
    assert f.errors?, "'now' function does not support parameters"
    
    f = FunctionResolver.new('days', [])
    f.validate
    assert f.errors?, "'days' function requires one parameter"
      
    f = FunctionResolver.new('days', [{:type => :character, :value=>'bad value'}])
    f.validate
    assert f.errors?, "'days' function needs integer parameter"
  end

  test "assert nil returned when function called with errors" do
    f = FunctionResolver.new('radius', [{:type => :character, 
        :value => "35.12 -68.33, 35.13 -68.34"},{:type => :decimal, 
        :value => 1.0}])
    assert_nil f.call
  end
  
  test "return_type" do 
    f = FunctionResolver.new('radius', [{:type => :character, 
        :value => "35.12 -68.33, 35.13 -68.34"},{:type => :decimal, 
        :value => 1.0}])
    assert_equal :shape, f.return_type
  end

  test 'return_type for cast()' do
    f = FunctionResolver.new('cast', [{:type => :character, 
        :value => "1"},{:type => :character, 
        :value => 'decimal'}])

    assert_equal :decimal, f.return_type

    f = FunctionResolver.new('cast', [{:type => :character, 
        :value => "1"},{:type => :character, 
        :value => 'integer'}])

    assert_equal :integer, f.return_type
  end

  test "cast() decimal to integer" do
    f = FunctionResolver.new('cast', [{:type => :decimal, :value => '1.2'}, {type: :character, :value => 'integer'}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :integer, value[:type]
    assert_equal '1', value[:value]
  end

  test "cast() integer to decimal" do
    f = FunctionResolver.new('cast', [{:type => :decimal, :value => '1'}, {type: :character, :value => 'decimal'}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :decimal, value[:type]
    assert_equal '1.0', value[:value]
  end

  test "cast() nil to integer" do
    f = FunctionResolver.new('cast', [{:type => :null, :value => 'NULL'}, {type: :character, :value => 'integer'}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :integer, value[:type]
    assert_equal '0', value[:value]
  end

  test "cast() nil to decimal" do
    f = FunctionResolver.new('cast', [{:type => :null, :value => 'NULL'}, {type: :character, :value => 'decimal'}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :decimal, value[:type]
    assert_equal '0.0', value[:value]
  end

  test "cast() nil to character" do
    f = FunctionResolver.new('cast', [{:type => :null, :value => 'NULL'}, {type: :character, :value => 'character'}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :character, value[:type]
    assert_equal "''", value[:value]
  end

  test "cast() character to decimal" do
    f = FunctionResolver.new('cast', [{:type => :character, :value => "1.1"}, {type: :character, :value => 'decimal'}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :decimal, value[:type]
    assert_equal "1.1", value[:value]
  end

  test "cast() character to integer" do
    f = FunctionResolver.new('cast', [{:type => :character, :value => "1"}, {type: :character, :value => 'integer'}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :integer, value[:type]
    assert_equal "1", value[:value]
  end

  test "cast() Field" do
    f = FunctionResolver.new('cast', [{:type => :field, :value => 'Bedrooms'}, {type: :character, :value => 'character'}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :function, value[:type]
    assert_equal 'cast', value[:value]
    assert_equal ['Bedrooms', 'character'], value[:args].map { |v| v[:value]}
  end

  test "invalid cast returns null" do
    f = FunctionResolver.new('cast', [{:type => :character, :value => '1.1.1'}, {type: :character, :value => 'integer'}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call

    assert_equal :null, value[:type]
    assert_equal 'NULL', value[:value]
  end

  test "invalid function" do
    f = FunctionResolver.new('then', [])
    f.validate
    assert f.errors?, "'then' is not a function"
  end

  test "time(datetime)" do
    f = FunctionResolver.new('time', [{:type => :datetime, :value => EXAMPLE_DATE}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :time, value[:type]
    assert_equal '10:22:15.422804000', value[:value]
  end

  test "date(datetime)" do
    f = FunctionResolver.new('date', [{:type => :datetime, :value => EXAMPLE_DATE}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :date, value[:type]
    assert_equal '2013-07-26', value[:value]
  end

###
# Delayed functions. These functions don't get run immediately and require
#  resolution by the backing system
###
  
  test "time(field)" do
    f = FunctionResolver.new('time', [{:type => :field, :value => "OriginalEntryTimestamp"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :function, value[:type]
    assert_equal 'time', value[:value]
    assert_equal "OriginalEntryTimestamp", value[:args].first[:value]
  end
  
  test "date(field)" do
    f = FunctionResolver.new('date', [{:type => :field, :value => "OriginalEntryTimestamp"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :function, value[:type]
    assert_equal 'date', value[:value]
    assert_equal "OriginalEntryTimestamp", value[:args].first[:value]
  end

  test "startswith(), endswith() and contains()" do
    [{'startswith' => "^far"},
     {'endswith' => "far$"},
     {'contains' => "far"}].each do |test_case|
      function = test_case.keys.first
      expected_value = test_case[function]

      f = FunctionResolver.new(function, [{:type => :character, :value => "far"}])
      f.validate
      assert !f.errors?, "Errors #{f.errors.inspect}"
      value = f.call
      assert_equal :character, value[:type]
      assert_equal expected_value, value[:value]
      assert_equal 'regex', value[:function_name]
      assert_equal [value[:value], ''], value[:function_parameters]
    end
  end

  test 'wkt()' do
    f = FunctionResolver.new('wkt',
                             [{:type => :character,
                               :value => "SRID=12345;POLYGON((-127.89734578345 45.234534534,-127.89734578345 45.234534534,-127.89734578345 45.234534534,-127.89734578345 45.234534534))"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal GeoRuby::SimpleFeatures::Polygon, value[:value].class
  end

  test 'wkt() invalid params' do
    f = FunctionResolver.new('wkt',
                             [{:type => :character,
                               :value => "POLYGON((45.234534534))"}])
    f.validate
    f.call
    assert f.errors?
  end
end
