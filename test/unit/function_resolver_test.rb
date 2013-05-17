require 'test_helper'

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
  
  test "day()" do
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
