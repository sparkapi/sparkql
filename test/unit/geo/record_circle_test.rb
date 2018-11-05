# frozen_string_literal: true

require 'test_helper'

class SparkqlV2::Geo::RecordRadiusTest < Test::Unit::TestCase
  def test_valid_record_id
    assert SparkqlV2::Geo::RecordRadius.valid_record_id?('20100000000000000000000000')

    ['2010000000000000000000000',
     '201000000000000000000000000',
     'test',
     '12.45,-96.5'].each do |bad_record_id|
       assert !SparkqlV2::Geo::RecordRadius.valid_record_id?(bad_record_id),
              "'#{bad_record_id}' should not be a valid record_id"
     end
  end
end
