# Custom fields need to add a table join to the customfieldsearch table when AND'd together,
# but not when they are OR'd or nested. This class maintains the state for all custom field expressions
# lets the parser know when to do either.
class Sparkql::ExpressionState
  def initialize
    @expressions = { 0 => [] }
    @last_conjunction = "And" # always start with a join
    @block_group = 0
  end

  def push(expression)
    @block_group = expression[:block_group]
    @expressions[@block_group] ||= []
    @expressions[@block_group] << expression
    @last_conjunction = expression[:conjunction]
  end

  def needs_join?
    @expressions[@block_group].size == 1 || %w[Not And].include?(@last_conjunction)
  end
end
