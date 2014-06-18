require 'test_helper'
require 'sparkql/geo'

class ParserTest < Test::Unit::TestCase
  include Sparkql

  test "function parameters and name preserved" do
    f = FunctionResolver.new('radius', [{:type => :character, 
          :value => "35.12 -68.33"},{:type => :decimal, :value => 1.0}])
    value = f.call
    assert_equal 'radius', value[:function_name]
    assert_equal(["35.12 -68.33", 1.0], value[:function_parameters])
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
    value = f.call
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
  
  test "rectangle()" do
    f = FunctionResolver.new('rectangle', [{:type => :character, :value => "35.12 -68.33, 35.13 -68.32"}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :shape, value[:type]
    assert_equal GeoRuby::SimpleFeatures::Polygon, value[:value].class
    assert_equal [[-68.33,35.12], [-68.32,35.12], [-68.32,35.13], [-68.33,35.13], [-68.33,35.12]], value[:value].to_coordinates.first, "#{value[:value].inspect} "
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
  
  test "invalid function" do
    f = FunctionResolver.new('then', [])
    f.validate
    assert f.errors?, "'then' is not a function"
  end
  
end
