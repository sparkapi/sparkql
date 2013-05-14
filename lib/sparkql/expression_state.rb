# Custom fields need to add a table join to the customfieldsearch table when AND'd together, 
# but not when they are OR'd. This class maintains the state for all custom field expressions
# lets the parser know when to do either.
class Sparkql::ExpressionState
  
  def initialize
    @expressions = []
    @last_conjunction = "And" # always start with a join
  end
  
  def push(expression)
    @expressions << expression
    @last_conjunction = expression[:conjunction]
  end
  
  def needs_join?
    return @expressions.size == 1 || ["Not", "And"].include?(@last_conjunction)
  end
  
end