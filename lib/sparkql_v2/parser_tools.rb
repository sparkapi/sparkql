# frozen_string_literal: true

# This is the guts of the parser internals and is mixed into the parser for organization.
module SparkqlV2
  module ParserTools
    # Coercible types from highest precision to lowest
    DATE_TYPES = ['datetime', 'date'].freeze
    NUMBER_TYPES = ['decimal', 'integer'].freeze
    OPERATORS_SUPPORTING_MULTIPLES = %w[Eq Ne Bt].freeze

    def parse(str)
      @lexer = SparkqlV2::Lexer.new(str)
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
        'name' => 'and',
        'lhs' => left,
        'rhs' => right
      }
    end

    def tokenize_or_conjunction(left, right)
      {
        'name' => 'or',
        'lhs' => left,
        'rhs' => right
      }
    end

    def tokenize_unary_not(expression)
      {
        'name' => 'unary_not',
        'value' => expression
      }
    end

    def tokenize_group(expression)
      {
        'name' => 'group',
        'value' => expression
      }
    end

    def tokenize_operator(field, operator, value)
      {
        'name' => operator.downcase,
        'lhs' => field,
        'rhs' => value
      }
    end

    def tokenize_list_operator(field, operator, values)
      if values.size == 1
        tokenize_operator(field, operator, values.first)
      else


        unless OPERATORS_SUPPORTING_MULTIPLES.include?(operator)
          tokenizer_error(token: operator,
                          message: "Operator #{operator} does not support multiple values",
                          status: :fatal)
        end

        list = {
          'name' => 'list',
          'value' => values
        }

        if operator == 'Bt'
          tokenize_operator(field, operator, list)
        elsif operator == 'Eq'
          tokenize_operator(field, 'In', list)
        elsif operator == 'Ne'
          tokenize_unary_not(tokenize_operator(field, 'In', list))
        end
      end
    end

    def tokenize_function_args(lit1, lit2)
      array = lit1.is_a?(Array) ? lit1 : [lit1]
      array << lit2
      array
    end

    def tokenize_field_arg(field)
      {
        'name' => 'field',
        'value' => field
      }
    end

    def tokenize_function(name, f_args)
      metadata = SemanticAnalyzer::FunctionAnalyzer::FUNCTION_METADATA
      function = metadata[name]

      if function.nil?
        msg = "function: #{name} does not exist"
        tokenizer_error(token: name,
                        message: msg,
                        status: :fatal,
                        syntax: true)
        return
      end

      args = function['arguments']
      min_args = args.select { |a| a['default'].nil? }.count
      max_args = args.count

      if !(min_args..max_args).include?(f_args.count)
        msg = "#{name} has wrong number of args! Expected between #{min_args} and #{max_args} but recieved #{f_args.count}"

        tokenizer_error(token: name,
                        message: msg,
                        status: :fatal,
                        syntax: true)
        return
      end

      {
        'function' => true,
        'name' => name,
        'args' => f_args
      }
    end

    def on_error(error_token_id, _error_value, _value_stack)
      token_name = token_to_str(error_token_id)
      tokenizer_error(token: @lexer.current_token_value,
                      message: "Error parsing token #{token_name.downcase}",
                      status: :fatal,
                      syntax: true)
    end

    def validate_expressions(results)
      if false
        compile_error(token: results[max_expressions]['field'], expression: results[max_expressions],
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
  end
end
