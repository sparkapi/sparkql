require 'test_helper'

class ParserTest < Test::Unit::TestCase
  include Sparkql

  def test_now
    start = Time.now
    f = FunctionResolver.new('now', [])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :datetime, value[:type]
    test_time = Time.parse(value[:value])
    assert (-5 < test_time - start && 5 > test_time - start), "Time range off by more than five seconds #{test_time - start} '#{test_time} - #{start}'"
  end
  
  def test_day
    d = Date.today + 1
    dt = DateTime.new(d.year, d.month,d.day, 0,0,0, DateTime.now.offset)
    start = Time.parse(dt.to_s)
    f = FunctionResolver.new('days', [{:type=>:integer, :value =>7}])
    f.validate
    assert !f.errors?, "Errors #{f.errors.inspect}"
    value = f.call
    assert_equal :datetime, value[:type]
    test_time = Time.parse(value[:value])
    assert (605000 > test_time - start && 604000 < test_time - start), "Time range off by more than five seconds #{test_time - start} '#{test_time} - #{start}'"
  end
  
  def test_invalid_param
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
  
  def test_invalid_function
    f = FunctionResolver.new('then', [])
    f.validate
    assert f.errors?, "'then' is not a function"
  end
  
end
