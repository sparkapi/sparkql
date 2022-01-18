# This is the guts of the parser internals and is mixed into the parser for organization.
require 'bigdecimal'

module Sparkql::ParserTools
  # Coercible types from highest precision to lowest
  DATE_TYPES = %i[datetime date].freeze
  NUMBER_TYPES = %i[decimal integer].freeze
  ARITHMETIC_TYPES = %i[decimal integer field arithmetic].freeze
  GROUP = 'Group'.freeze
  NEGATION = 'Negation'.freeze

  def parse(str)
    @lexer = Sparkql::Lexer.new(str)
    @expression_count = 0
    results = do_parse
    return if results.nil?

    validate_expressions results
    results
  end

  def next_token
    t = @lexer.shift
    t = @lexer.shift while (t[0] == :SPACE) || (t[0] == :NEWLINE)
    t
  end

  def arithmetic_field(nested_representation)
    return if nested_representation.nil?

    return nested_representation[:value] if nested_representation[:type] == :field
    return nested_representation[:field] if nested_representation.key?(:field)

    field = arithmetic_field(nested_representation[:lhs])
    return field unless field.nil?

    field = arithmetic_field(nested_representation[:rhs])
    return field unless field.nil?
  end

  def no_field_error(field, operator)
    tokenizer_error(token: field,
                    expression: { operator: operator, conjuction: 'And', conjunction_level: 0, level: @lexer.level },
                    message: "Each expression must evaluate a field", status: :fatal)
  end

  def tokenize_expression(field, op_token, val)
    operator = get_operator(val, op_token) unless val.nil?

    field_manipulations = nil
    if field.is_a?(Hash) && field[:type] == :function
      unless supported_function?(field[:function_name])
        tokenizer_error(token: field[:function_name],
                        message: 'Unsupported function type',
                        status: :fatal)
      end
      field_manipulations = field
      field = field[:field]
    elsif field.is_a?(Hash) && field[:type] == :arithmetic
      field_manipulations = field
      field = arithmetic_field(field)
      no_field_error(field, operator) if field.nil?
    elsif field.is_a?(Hash)
      no_field_error(field, operator)
    end

    custom_field = !field.nil? && field.is_a?(String) && field.start_with?('"')

    block_group = @lexer.level.zero? ? 0 : @lexer.block_group_identifier
    expression = { field: field, operator: operator, conjunction: 'And',
                   conjunction_level: 0, level: @lexer.level,
                   block_group: block_group, custom_field: custom_field }

    if !field_manipulations.nil?
      # Keeping field_function and field_function_type for backward compatibility with datacon
      expression.merge!(field_manipulations: field_manipulations)

      if field_manipulations[:type] == :function
        expression.merge!(field_function: field_manipulations[:function_name],
                          field_function_type: field_manipulations[:return_type],
                          args: field_manipulations[:function_parameters])
      end
    end

    expression = val.merge(expression) unless val.nil?
    expression[:condition] ||= expression[:value]
    validate_level_depth expression
    validate_field_function_depth(expression[:field_manipulations])
    if operator.nil?
      tokenizer_error(token: op_token, expression: expression,
                      message: "Operator not supported for this type and value string", status: :fatal)
    end
    @expression_count += 1
    [expression]
  end

  def tokenize_conjunction(exp1, conj, exp2)
    exp2.first[:conjunction] = conj
    exp2.first[:conjunction_level] = @lexer.level
    exp1 + exp2
  end

  def tokenize_unary_conjunction(conj, exp)
    # Handles the case when a SparkQL filter string
    # begins with a unary operator, and is nested, such as:
    #   Not (Not Field Eq 1)
    # In this instance we treat the outer unary as a conjunction. With any other
    # expression this would be the case, so that should make processing
    # consistent.
    if exp.first[:unary] && @lexer.level.zero?
      exp.first[:conjunction] = conj
      exp.first[:conjunction_level] = @lexer.level
    else
      exp.first[:unary] = conj
      exp.first[:unary_level] = @lexer.level
    end

    exp
  end

  def tokenize_group(expressions)
    @lexer.leveldown
    expressions
  end

  def tokenize_arithmetic_group(lhs)
    @lexer.leveldown
    @lexer.block_group_identifier -= 1
    lhs = { type: :field, value: lhs } if lhs.is_a?(String)
    {
      type: :arithmetic,
      op: GROUP,
      lhs: lhs
    }
  end

  def tokenize_arithmetic_negation(lhs)
    lhs = { type: :field, value: lhs } if lhs.is_a?(String)
    {
      type: :arithmetic,
      op: NEGATION,
      lhs: lhs
    }
  end

  def tokenize_list(list)
    return if list.nil?

    validate_multiple_values list[:value]
    list[:condition] ||= list[:value]
    list
  end

  def tokenize_literal_negation(number_token)
    old_val = case number_token[:type]
              when :integer
                number_token[:value].to_i
              when :decimal
                number_token[:value].to_f
              else
                tokenizer_error(token: @lexer.current_token_value,
                                expression: number_token,
                                message: "Negation is only allowed for integer and floats",
                                status: :fatal,
                                syntax: true)
                return number_token
              end
    number_token[:value] = (-1 * old_val).to_s

    number_token
  end

  def tokenize_multiple(lit1, lit2)
    final_type = lit1[:type]
    if lit1[:type] != lit2[:type]
      final_type = coercible_types(lit1[:type], lit2[:type])
      if final_type.nil?
        final_type = lit1[:type]
        tokenizer_error(token: @lexer.last_field,
                        message: "Type mismatch in field list.",
                        status: :fatal,
                        syntax: true)
      end
    end
    array = Array(lit1[:value])
    condition = lit1[:condition] || lit1[:value]
    array << lit2[:value]
    {
      type: final_type,
      value: array,
      multiple: "true",
      condition: "#{condition},#{lit2[:condition] || lit2[:value]}"
    }
  end

  def tokenize_function_args(lit1, lit2)
    array = lit1.is_a?(Array) ? lit1 : [lit1]
    array << lit2
    array
  end

  def tokenize_field_arg(field)
    if field.is_a?(String)
      {
        type: :field,
        value: field
      }
    else
      field
    end
  end

  def tokenize_function(name, f_args)
    @lexer.leveldown
    @lexer.block_group_identifier -= 1

    args = f_args.instance_of?(Array) ? f_args : [f_args]
    validate_multiple_arguments args
    condition_list = []
    args.each do |arg|
      condition_list << arg[:value] # Needs to be pure string value
      arg[:value] = escape_value(arg)
    end
    resolver = function_resolver(name, args)
    resolver.validate
    if resolver.errors?
      tokenizer_error(token: @lexer.last_field,
                      message: "Error parsing function #{resolver.errors.join(',')}",
                      status: :fatal,
                      syntax: true)
      nil
    else
      result = resolver.call
      result.nil? ? result : result.merge(condition: "#{name}(#{condition_list.join(',')})")
    end
  end

  def tokenize_arithmetic(lhs, operator, rhs)
    lhs = { type: :field, value: lhs } if lhs.is_a?(String)
    rhs = { type: :field, value: rhs } if rhs.is_a?(String)

    arithmetic_error?(lhs)
    arithmetic_error?(rhs)
    {
      type: :arithmetic,
      op: operator,
      lhs: lhs,
      rhs: rhs
    }
  end

  def arithmetic_error?(side)
    side_type = side[:type] == :function ? side[:return_type] : side[:type]
    return false if ARITHMETIC_TYPES.include?(side_type)

    compile_error(token: side[:value], expression: side,
                  message: "Error attempting arithmetic with type: #{side_type}",
                  status: :fatal, syntax: false, constraint: true)
    true
  end

  def group_fold(exp)
    @lexer.leveldown
    @lexer.block_group_identifier -= 1
    exp
  end

  def add_fold(node1, node2)
    return if arithmetic_error?(node1) || arithmetic_error?(node2)

    value = escape_arithmetic_value(node1) + escape_arithmetic_value(node2)
    { type: arithmetic_type(node1, node2), value: unescape_arithmetic(value) }
  end

  def sub_fold(node1, node2)
    return if arithmetic_error?(node1) || arithmetic_error?(node2)

    value = escape_arithmetic_value(node1) - escape_arithmetic_value(node2)
    { type: arithmetic_type(node1, node2), value: unescape_arithmetic(value) }
  end

  def mul_fold(node1, node2)
    return if arithmetic_error?(node1) || arithmetic_error?(node2)

    value = escape_arithmetic_value(node1) * escape_arithmetic_value(node2)
    { type: arithmetic_type(node1, node2), value: unescape_arithmetic(value) }
  end

  def div_fold(node1, node2)
    return if arithmetic_error?(node1) ||
              arithmetic_error?(node2) ||
              zero_error?(node2)

    value = escape_arithmetic_value(node1) / escape_arithmetic_value(node2)
    { type: arithmetic_type(node1, node2), value: unescape_arithmetic(value) }
  end

  def mod_fold(node1, node2)
    return if arithmetic_error?(node1) ||
              arithmetic_error?(node2) ||
              zero_error?(node2)

    value = escape_arithmetic_value(node1) % escape_arithmetic_value(node2)
    { type: arithmetic_type(node1, node2), value: unescape_arithmetic(value) }
  end

  def arithmetic_type(num1, num2)
    if num1[:type] == :decimal || num2[:type] == :decimal
      :decimal
    else
      :integer
    end
  end

  def escape_arithmetic_value(expression)
    case expression[:type]
    when :decimal
      BigDecimal(expression[:value])
    else
      escape_value(expression)
    end
  end

  def unescape_arithmetic(value)
    if value.is_a?(BigDecimal)
      value.round(20).to_s('F')
    else
      value.to_s
    end
  end

  def zero_error?(number)
    return unless escape_value(number).zero?

    compile_error(token: (number[:value]).to_s, expression: number,
                  message: "Error attempting to divide by zero",
                  status: :fatal, syntax: false, constraint: true)
  end

  def on_error(error_token_id, _error_value, _value_stack)
    token_name = token_to_str(error_token_id)
    token_name.downcase!
    tokenizer_error(token: @lexer.current_token_value,
                    message: "Error parsing token #{token_name}",
                    status: :fatal,
                    syntax: true)
  end

  def validate_level_depth(expression)
    if @lexer.level > max_level_depth
      compile_error(token: "(", expression: expression,
                    message: "You have exceeded the maximum nesting level.  Please nest no more than #{max_level_depth} levels deep.",
                    status: :fatal, syntax: false, constraint: true)
    end
  end

  def validate_field_function_depth(expression)
    if nested_function_depth(expression) > max_function_depth
      compile_error(token: "(", expression: expression,
                    message: "You have exceeded the maximum function nesting level.  Please nest no more than #{max_function_depth} levels deep.",
                    status: :fatal, syntax: false, constraint: true)
    end
  end

  def validate_expressions(results)
    if results.size > max_expressions
      compile_error(token: results[max_expressions][:field], expression: results[max_expressions],
                    message: "You have exceeded the maximum expression count.  Please limit to no more than #{max_expressions} expressions in a filter.",
                    status: :fatal, syntax: false, constraint: true)
      results.slice!(max_expressions..-1)
    end
  end

  def validate_multiple_values(values)
    values = Array(values)
    if values.size > max_values
      compile_error(token: values[max_values],
                    message: "You have exceeded the maximum value count.  Please limit to #{max_values} values in a single expression.",
                    status: :fatal, syntax: false, constraint: true)
      values.slice!(max_values..-1)
    end
  end

  def validate_multiple_arguments(args)
    args = Array(args)
    if args.size > max_values
      compile_error(token: args[max_values],
                    message: "You have exceeded the maximum parameter count.  Please limit to #{max_values} parameters to a single function.",
                    status: :fatal, syntax: false, constraint: true)
      args.slice!(max_values..-1)
    end
  end

  # If both types support coercion with eachother, always selects the highest
  # precision type to return as a reflection of the two. Any type that doesn't
  # support coercion with the other type returns nil
  def coercible_types(type1, type2)
    if DATE_TYPES.include?(type1) && DATE_TYPES.include?(type2)
      DATE_TYPES.first
    elsif NUMBER_TYPES.include?(type1) && NUMBER_TYPES.include?(type2)
      NUMBER_TYPES.first
    else
      nil
    end
  end

  def nested_function_depth(expression)
    return 0 unless expression && expression[:type] == :function

    height = 0
    queue = []
    queue.push(expression)

    loop do
      count = queue.size
      return height if count.zero?

      height += 1

      while count.positive?
        node = queue.shift
        node[:args].each do |child|
          queue.push(child) if child[:type] == :function
        end
        count -= 1
      end
    end
  end

  def function_resolver(function_name, function_args = [])
    Sparkql::FunctionResolver.new(function_name,
                                  function_args,
                                  current_timestamp: current_timestamp)
  end

  def supported_function?(function_name)
    !lookup_function(function_name).nil?
  end

  def lookup_function(function_name)
    Sparkql::FunctionResolver.lookup(function_name)
  end

  def current_timestamp
    @current_timestamp ||= DateTime.now
  end

  def offset
    @offset ||= current_timestamp.zone
  end
end
