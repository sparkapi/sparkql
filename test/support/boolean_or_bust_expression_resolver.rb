# frozen_string_literal: true

# A super simple expression resolver for testing... returns the boolean value as
# the result for the expression, or when not a boolean, drops the expression.
class BooleanOrBustExpressionResolver < Sparkql::ExpressionResolver
  def resolve(expression)
    if expression['type'] == :boolean
      expression['value'] == 'true'
    else
      'drop'
    end
  end
end
