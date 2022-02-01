# Using an instance of ExpressionResolver to resolve the individual expressions,
# this class will evaluate the rest of a parsed sparkql string to true or false.
# Namely, this class will handle all the nesting, boolean algebra, and dropped
# fields. Plus, it has some optimizations built in to skip the processing for
# any expressions that don't contribute to the net result of the filter.
class Sparkql::Evaluator
  # The struct here mimics some of the parser information about an expression,
  # but should not be confused for an expression. Nodes reduce the expressions
  # to a result based on conjunction logic, and only one exists per block group.
  Node = Struct.new(
    :level,
    :block_group,
    :conjunction,
    :conjunction_level,
    :match,
    :good_ors,
    :expressions,
    :unary
  )

  attr_reader :processed_count

  def initialize(expression_resolver)
    @resolver = expression_resolver
  end

  def evaluate(expressions)
    @dropped_expression = nil
    @processed_count = 0
    @index = Node.new(0, 0, "And", 0, true, false, 0, nil)
    @groups = [@index]
    expressions.each do |expression|
      handle_group(expression)
      adjust_expression_for_dropped_field(expression)
      check_for_good_ors(expression)
      next if skip?(expression)

      evaluate_expression(expression)
    end
    cleanup
    @index[:match]
  end

  private

  # prepare the group stack for the next expression
  def handle_group(expression)
    if @index[:block_group] == expression[:block_group]
      # Noop
    elsif @index[:block_group] < expression[:block_group]
      @index = new_group(expression)
      @groups.push(@index)
    else
      # Turn the group into an expression, resolve down to previous group(s)
      smoosh_group(expression)
    end
  end

  # Here's the real meat. We use an internal stack to represent the result of
  # each block_group. This logic is re-used when merging the final result of one
  # block group with the previous.
  def evaluate_expression(expression)
    @processed_count += 1
    evaluate_node(expression, @resolver.resolve(expression))
  end

  def evaluate_node(node, result)
    if result == :drop
      @dropped_expression = node
      return result
    end
    if node[:unary] == "Not"
      result = !result
    end
    if node[:conjunction] == 'Not' &&
       (node[:conjunction_level] == node[:level] ||
        node[:conjunction_level] == @index[:level])
      @index[:match] = !result if @index[:match]
    elsif node[:conjunction] == 'And' || (@index[:expressions]).zero?
      @index[:match] = result if @index[:match]
    elsif node[:conjunction] == 'Or' && result
      @index[:match] = result
    end
    @index[:expressions] += 1
    result
  end

  # Optimization logic, once we find any set of And'd expressions that pass and
  # run into an Or at the same level, we can skip further processing at that
  # level.
  def check_for_good_ors(expression)
    if expression[:conjunction] == 'Or'
      good_index = @index
      unless expression[:conjunction_level] == @index[:level]
        good_index = nil
        # Well crap, now we need to go back and find that level by hand
        @groups.reverse_each do |i|
          if i[:level] == expression[:conjunction_level]
            good_index = i
          end
        end
      end
      if !good_index.nil? && (good_index[:expressions]).positive? && good_index[:match]
        good_index[:good_ors] = true
      end
    end
  end

  # We can skip further expression processing when And-d with a false expression
  # or a "good Or" was already encountered.
  def skip?(expression)
    @index[:good_ors] ||
      !@index[:match] && expression[:conjunction] == 'And'
  end

  def new_group(expression)
    Node.new(expression[:level], expression[:block_group],
             expression[:conjunction], expression[:conjunction_level],
             true, false, 0, nil)
  end

  # When the last expression was dropped, we need to repair the filter by
  # stealing the conjunction of that dropped field.
  def adjust_expression_for_dropped_field(expression)
    if @dropped_expression.nil?
      return
    elsif @dropped_expression[:block_group] == expression[:block_group]
      expression[:conjunction] = @dropped_expression[:conjunction]
      expression[:conjunction_level] = @dropped_expression[:conjunction_level]
    end

    @dropped_expression = nil
  end

  # This is similar to the cleanup step, but happens when we return from a
  # nesting level. Before we can proceed, we need wrap up the result of the
  # nested group.
  def smoosh_group(expression)
    until  @groups.last[:block_group] == expression[:block_group]
      last = @groups.pop
      @index = @groups.last
      evaluate_node(last, last[:match])
    end
  end

  # pop off the group stack, evaluating each group with the previous as we go.
  def cleanup
    while @groups.size > 1
      last = @groups.pop
      @index = @groups.last
      evaluate_node(last, last[:match])
    end
    @groups.last[:match]
  end
end
