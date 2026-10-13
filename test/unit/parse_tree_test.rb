require 'test_helper'

class ParseTreeTest < Test::Unit::TestCase
  include Sparkql

  def setup
    @parser = Parser.new
  end

  # Renders a tree compactly by field name, e.g. "Or[A, And[B, C]]".
  def shape(node)
    case node[:node]
    when :expression then node[:expression][:field]
    when :group then "(#{shape(node[:operand])})"
    when :unary then "#{node[:unary]} #{shape(node[:operand])}"
    when :conjunction then "#{node[:conjunction]}[#{shape(node[:left])}, #{shape(node[:right])}]"
    end
  end

  def assert_shape(expected, filter)
    tree = @parser.parse_tree(filter)
    assert !@parser.errors?, "#{filter}: #{@parser.errors.map(&:message)}"
    assert_equal expected, shape(tree), filter
  end

  def leaves(node)
    case node[:node]
    when :expression then [node[:expression]]
    when :group, :unary then leaves(node[:operand])
    when :conjunction then leaves(node[:left]) + leaves(node[:right])
    end
  end

  def test_single_expression
    tree = @parser.parse_tree('Test Eq 10')

    assert_equal :expression, tree[:node]
    assert_equal 'Test', tree[:expression][:field]
    assert_equal 'Eq', tree[:expression][:operator]
    assert_equal '10', tree[:expression][:value]
  end

  def test_conjunctions_of_one_kind_group_left_to_right
    assert_shape 'And[And[A, B], C]', 'A Eq 1 And B Eq 1 And C Eq 1'
    assert_shape 'Or[Or[A, B], C]', 'A Eq 1 Or B Eq 1 Or C Eq 1'
  end

  def test_and_binds_tighter_than_or
    assert_shape 'Or[A, And[B, C]]', 'A Eq 1 Or B Eq 1 And C Eq 1'
    assert_shape 'Or[And[A, B], C]', 'A Eq 1 And B Eq 1 Or C Eq 1'
    assert_shape 'Or[And[A, B], And[C, D]]', 'A Eq 1 And B Eq 1 Or C Eq 1 And D Eq 1'
    assert_shape 'Or[Or[A, And[B, C]], D]', 'A Eq 1 Or B Eq 1 And C Eq 1 Or D Eq 1'
  end

  # A binary Not means "And Not", so it binds like And.
  def test_binary_not_binds_like_and
    assert_shape 'Or[A, Not[B, C]]', 'A Eq 1 Or B Eq 1 Not C Eq 1'
    assert_shape 'Or[Not[And[A, B], C], D]', 'A Eq 1 And B Eq 1 Not C Eq 1 Or D Eq 1'
  end

  def test_groups_override_precedence
    assert_shape 'And[(Or[A, B]), C]', '(A Eq 1 Or B Eq 1) And C Eq 1'
    assert_shape 'Or[A, And[B, (Or[C, And[D, E]])]]', 'A Eq 1 Or B Eq 1 And (C Eq 1 Or D Eq 1 And E Eq 1)'
  end

  # The flat #parse list can't represent these: the middle group has no
  # expression of its own, and block_group is the most recently opened group
  # rather than the containing one.
  def test_sibling_groups_keep_their_structure
    assert_shape 'And[(A), (Or[(B), (C)])]', '(A Eq 1) And ((B Eq 1) Or (C Eq 1))'
    assert_shape 'Or[(And[A, (B)]), (And[(C), D])]', '(A Eq 1 And (B Eq 1)) Or ((C Eq 1) And D Eq 1)'
  end

  def test_unary_not_applies_to_the_following_comparison_or_group
    assert_shape 'And[Not A, B]', 'Not A Eq 1 And B Eq 1'
    assert_shape 'And[Not (Or[A, B]), C]', 'Not (A Eq 1 Or B Eq 1) And C Eq 1'
    assert_shape 'Not (Not A)', 'Not (Not A Eq 1)'
  end

  def test_conjunction_and_unary_nodes_carry_their_levels
    tree = @parser.parse_tree('Not (A Eq 1 Or B Eq 1) And C Eq 1')
    unary = tree[:left]
    inner_or = unary[:operand][:operand]

    assert_equal [:conjunction, 'And', 0], tree.values_at(:node, :conjunction, :conjunction_level)
    assert_equal [:unary, 'Not', 0], unary.values_at(:node, :unary, :unary_level)
    assert_equal [:conjunction, 'Or', 1], inner_or.values_at(:node, :conjunction, :conjunction_level)
  end

  # A tree's leaves are the same expression Hashes #parse returns, with the
  # same flat metadata.
  def test_leaves_match_parse_output
    [
      'A Eq 1 Or B Eq 1 And C Eq 1',
      '(A Eq 1) And ((B Eq 1) Or (C Eq 1))',
      'Not (A Eq 1 Or B Eq 1) And C Eq 1',
      'Not (Not A Eq 1)',
      "A Eq 1 Not (B Eq 'x' Or C Bt 1,2)"
    ].each do |filter|
      assert_equal Parser.new.parse(filter), leaves(@parser.parse_tree(filter)), filter
    end
  end

  def test_empty_filter_is_nil
    assert_nil @parser.parse_tree('')
    assert !@parser.errors?
  end

  def test_syntax_error_is_nil_with_errors
    assert_nil @parser.parse_tree('A Eq 1 And')
    assert @parser.fatal_errors?
  end

  def test_validation_errors_are_reported_like_parse
    filter = (1..80).map { |i| "F#{i} Eq #{i}" }.join(' And ')
    tree = @parser.parse_tree(filter)

    assert_not_nil tree
    assert(@parser.errors.any? { |e| e.message.include?('maximum expression count') })

    nested = Parser.new
    nested.parse_tree('A Eq 1 And (((B Eq 1)))')
    assert(nested.errors.any? { |e| e.message.include?('maximum nesting level') })
  end

  def test_parser_can_be_reused
    assert_shape 'And[A, B]', 'A Eq 1 And B Eq 1'
    assert_shape 'Or[C, D]', 'C Eq 1 Or D Eq 1'
  end
end
