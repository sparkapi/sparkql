# This is the guts of the parser internals and is mixed into the parser for organization.
module Sparkql::ParserTools

  # Coercible types from highest precision to lowest
  DATE_TYPES = [:datetime, :date]
  NUMBER_TYPES = [:decimal, :integer]
  
  def parse(str)
    @lexer = Sparkql::Lexer.new(str)
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
  
  def tokenize_expression(field, op, val)
    operator = get_operator(val,op) unless val.nil?
    custom_field = field.start_with?('"')
    block_group = (@lexer.level == 0) ? 0 : @lexer.block_group_identifier
    expression = {:field => field, :operator => operator, :conjunction => 'And', 
      :level => @lexer.level, :block_group => block_group, :custom_field => custom_field}
    expression = val.merge(expression) unless val.nil?
    validate_level_depth expression
    if operator.nil?
      tokenizer_error(:token => op, :expression => expression,
        :message => "Operator not supported for this type and value string", :status => :fatal )
    end
    [expression]
  end
  
  def tokenize_conjunction(exp1, conj, exp2)
    exp2.first[:conjunction] = conj
    exp2.first[:conjunction_level] = @lexer.level
    exp1 + exp2
  end

  def tokenize_unary_conjunction(exp1, conj, exp2)
    #Unary conjuncion 'Not' is 'And Not'

    exp2.first[:conjunction] = 'And'
    exp2.first[:conjunction_level] = @lexer.level

    flip_expression_if_necessary(exp2, conj)

    exp1 + exp2
  end

  def tokenize_unary(conj, exp)
    flip_expression_if_necessary(exp, conj)
    exp.first[:unary_level] = @lexer.level
    exp
  end

  def flip_expression_if_necessary(exp, conj)
    if exp.first[:unary].nil?
      exp.first[:unary] = conj
    else
      exp.first.delete(:unary)
    end
  end

  def tokenize_group(expressions)
    @lexer.leveldown
    expressions
  end

  def tokenize_list(list)
    validate_multiple_values list[:value]
    list[:condition] ||= list[:value]
    list
  end

  def tokenize_multiple(lit1, lit2)
    final_type = lit1[:type]
    if lit1[:type] != lit2[:type]
      final_type = coercible_types(lit1[:type],lit2[:type])
      if final_type.nil?
        final_type = lit1[:type]
        tokenizer_error(:token => @lexer.last_field, 
                        :message => "Type mismatch in field list.",
                        :status => :fatal, 
                        :syntax => true)
      end
    end
    array = Array(lit1[:value])
    condition = lit1[:condition] || lit1[:value] 
    array << lit2[:value]
    {
      :type => final_type ,
      :value => array,
      :multiple => "true",
      :condition => condition + "," + (lit2[:condition] || lit2[:value])
    }
  end
  
  def tokenize_function_args(lit1, lit2)
    array = lit1.kind_of?(Array) ? lit1 : [lit1]
    array << lit2
    array
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
    resolver = Sparkql::FunctionResolver.new(name, args)
    
    resolver.validate
    if(resolver.errors?)
      tokenizer_error(:token => @lexer.last_field, 
                      :message => "Error parsing function #{resolver.errors.join(',')}",
                      :status => :fatal, 
                      :syntax => true)    
      return nil
    else
      result = resolver.call()
      return result.nil? ? result : result.merge(:condition => "#{name}(#{condition_list.join(',')})")
    end
  end
  
  def on_error(error_token_id, error_value, value_stack)
    token_name = token_to_str(error_token_id)
    token_name.downcase!
    token = error_value.to_s.inspect
    tokenizer_error(:token => @lexer.last_field, 
                    :message => "Error parsing token #{token_name}",
                    :status => :fatal, 
                    :syntax => true)    
  end  

  def validate_level_depth expression
    if @lexer.level > max_level_depth
      compile_error(:token => "(", :expression => expression,
            :message => "You have exceeded the maximum nesting level.  Please nest no more than #{max_level_depth} levels deep.",
            :status => :fatal, :syntax => false, :constraint => true )
    end
  end
  
  def validate_expressions results
    if results.size > max_expressions 
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
  
  # If both types support coercion with eachother, always selects the highest 
  # precision type to return as a reflection of the two. Any type that doesn't
  # support coercion with the other type returns nil
  def coercible_types type1, type2
    if DATE_TYPES.include?(type1) && DATE_TYPES.include?(type2)
      DATE_TYPES.first
    elsif NUMBER_TYPES.include?(type1) && NUMBER_TYPES.include?(type2)
      NUMBER_TYPES.first
    else
      nil
    end
  end

end
