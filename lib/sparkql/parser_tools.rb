# This is the guts of the parser internals and is mixed into the parser for organization.
module Sparkql::ParserTools

  # Coercible types from highest precision to lowest
  DATE_TYPES = [:datetime, :date]
  NUMBER_TYPES = [:decimal, :integer]
  OPERATORS_SUPPORTING_MULTIPLES = ['Eq','Ne', 'Bt']

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
    while t[0] == :SPACE or t[0] == :NEWLINE
      t = @lexer.shift
    end
    t
  end

  def tokenize_conjunction(exp1, conj, exp2)
    case conj
    when 'And'
      tokenize_and_conjunction(exp1, exp2)
    when 'Or'
      tokenize_or_conjunction(exp1, exp2)
    when 'Not'
      tokenize_and_conjunction(exp1, tokenize_unary_not(exp2))
    else
      raise "#{conj} is not supported"
    end
  end

  def tokenize_and_conjunction(left, right)
    {
      name: :and,
      lhs: left,
      rhs: right
    }
  end

  def tokenize_or_conjunction(left, right)
    {
      name: :or,
      lhs: left,
      rhs: right
    }
  end

  def tokenize_unary_not(expression)
    {
      name: :unary_not,
      value: expression
    }
  end

  def tokenize_group(expression)
    {
      name: :group,
      value: expression
    }
  end

  def tokenize_operator(field, operator, value)
    {
      name: operator.downcase.to_sym,
      lhs: field,
      rhs: value
    }
  end

  def tokenize_list_operator(field, operator, values)
    if values.size == 1
      tokenize_operator(field, operator, values.first)
    else

      if !OPERATORS_SUPPORTING_MULTIPLES.include?(operator)
        tokenizer_error(token: operator,
                        message: "Operator #{operator} does not support multiple values",
                        status: :fatal)
      end

      if operator == 'Bt'
        tokenize_operator(field, operator, values)
      elsif operator == 'Eq'
        tokenize_operator(field, 'In', values)
      elsif operator == 'Ne'
        tokenize_unary_not(tokenize_operator(field, 'In', values))
      end
    end
  end

  def tokenize_function_args(lit1, lit2)
    array = lit1.kind_of?(Array) ? lit1 : [lit1]
    array << lit2
    array
  end

  def tokenize_field_arg(field)
    {
      name: :field,
      value: field
    }
  end

  def tokenize_function(name, f_args)
    method = name.to_sym

    if !Sparkql::FUNCTION_METADATA.key?(method)
      tokenizer_error(token: name,
        message: "Unsupported function call '#{name}' for expression",
        status: :fatal)
      return
    end

    function = {
      function: true,
      name: method,
      args: f_args
    }

=begin
    function = Sparkql::Nodes::Functions.const_get(constant_name).new(f_args)
    function.errors.each do |error|
      compile_error(error)
    end
=end

    function
  end

  def on_error(error_token_id, error_value, value_stack)
    token_name = token_to_str(error_token_id)
    token_name.downcase!
    tokenizer_error(:token => @lexer.current_token_value,
                    :message => "Error parsing token #{token_name}",
                    :status => :fatal,
                    :syntax => true)
  end

  def validate_expressions results
    if false
      compile_error(:token => results[max_expressions][:field], :expression => results[max_expressions],
            :message => "You have exceeded the maximum expression count.  Please limit to no more than #{max_expressions} expressions in a filter.",
            :status => :fatal, :syntax => false, :constraint => true )
      results.slice!(max_expressions..-1)
    end
  end

  def validate_multiple_values values
    values = Array(values)
    if values.size > max_values
      compile_error(:token => values[max_values],
            :message => "You have exceeded the maximum value count.  Please limit to #{max_values} values in a single expression.",
            :status => :fatal, :syntax => false, :constraint => true )
      values.slice!(max_values..-1)
    end
  end

  def validate_multiple_arguments args
    args = Array(args)
    if args.size > max_values
      compile_error(:token => args[max_values],
            :message => "You have exceeded the maximum parameter count.  Please limit to #{max_values} parameters to a single function.",
            :status => :fatal, :syntax => false, :constraint => true )
      args.slice!(max_values..-1)
    end
  end

end
