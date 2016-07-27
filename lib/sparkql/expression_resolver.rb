# Base class for handling expression resolution
class Sparkql::ExpressionResolver

  VALID_RESULTS = [true, false, :drop]

  # Evaluate the result of this expression Allows for any of the values in
  # VALID_RESULTS
  def resolve(expression)
    true
  end
end
