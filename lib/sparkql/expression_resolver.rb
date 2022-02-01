# Base class for handling expression resolution
class Sparkql::ExpressionResolver
  # Accepted results from the resolve method:
  # * true and false reflect the expression's boolean result (as all expressions
  #   should).
  # * :drop is a special symbol indicating that the expression should be omitted
  #   from the filter. Special rules apply for a dropped expression, such as
  #   keeping the conjunction of the dropped expression.
  VALID_RESULTS = [true, false, :drop].freeze

  # Evaluate the result of this expression. Allows for any of the values in
  # VALID_RESULTS
  def resolve(_expression)
    true
  end
end
