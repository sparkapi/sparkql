require 'test_helper'
require 'sparkql/geo'

class FunctionResolverTest < Test::Unit::TestCase
  include Sparkql
  
  EXAMPLE_DATE = DateTime.parse("2013-07-26T10:22:15.422804")

=begin
  # TODO: Optimizations
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
=end

###
# Delayed functions. These functions don't get run immediately and require
#  resolution by the backing system
###

=begin
KEEPING FOR REFERENCE
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
=end


end
