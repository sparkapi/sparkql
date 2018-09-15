# frozen_string_literal: true

require 'test_helper'

class ParserTest < Test::Unit::TestCase
  include Sparkql

  def test_error_defaults
    errors = ParserError.new
    assert errors.syntax?
    assert !errors.constraint?
  end

  def test_error_constraint
    errors = ParserError.new(constraint: true, syntax: false)
    assert !errors.syntax?
    assert errors.constraint?
  end

  def test_process_fatal_errors
    p = ErrorsProcessor.new(ParserError.new(status: :fatal))
    assert p.fatal_errors?
    assert !p.dropped_errors?
  end

  def test_process_dropped_errors
    p = ErrorsProcessor.new(ParserError.new(status: :dropped))
    assert p.dropped_errors?
    assert !p.fatal_errors?
  end
end
