# This is the guts of the parser internals and is mixed into the parser for organization.
module Sparkql::ParserTools

  # Coercible types from highest precision to lowest
  DATE_TYPES = [:datetime, :date]
  NUMBER_TYPES = [:decimal, :integer]
  
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
  
  def tokenize_expression(field, op, val)
    operator = get_operator(val,op) unless val.nil?
    field_args = {}
    # Function support for fields is stapled in here. The function information
    # is remapped to the expression
    if field.is_a?(Hash) && field[:type] == :function
      function = Sparkql::FunctionResolver::SUPPORTED_FUNCTIONS[field[:value].to_sym]
      if !function.nil?
        field_args[:field_function] = field[:value]
        field_args[:field_function_type] = function[:return_type]
        field_args[:args] = field[:args]
      else
        tokenizer_error(:token => field[:value], 
          :message => "Unsupported function type", :status => :fatal )
      end
      field = field[:args].first
    end
    custom_field = field.start_with?('"')
    block_group = (@lexer.level == 0) ? 0 : @lexer.block_group_identifier
    expression = {:field => field, :operator => operator, :conjunction => 'And',
      :conjunction_level => 0, :level => @lexer.level,
      :block_group => block_group, :custom_field => custom_field}.
      merge!(field_args)
    expression = val.merge(expression) unless val.nil?
    expression[:condition] ||= expression[:value]
    validate_level_depth expression
    if operator.nil?
      tokenizer_error(:token => op, :expression => expression,
        :message => "Operator not supported for this type and value string", :status => :fatal )
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
    if exp.first[:unary] && @lexer.level == 0
      exp.first[:conjunction] =  conj
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

  def tokenize_list(list)
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
      tokenizer_error(:token => @lexer.current_token_value,
                      :expression => number_token,
                      :message => "Negation is only allowed for integer and floats",
                      :status => :fatal,
                      :syntax => true)
      return number_token
    end
    number_token[:value] = (-1 * old_val).to_s

    number_token
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
  
  def tokenize_field_arg(field)
    {
      :type => :field,
      :value => field,
    }
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
      result.nil? ? result : result.merge(:condition => "#{name}(#{condition_list.join(',')})")
    end
  end
  
  def on_error(error_token_id, error_value, value_stack)
    token_name = token_to_str(error_token_id)
    token_name.downcase!
    token = error_value.to_s.inspect
    tokenizer_error(:token => @lexer.current_token_value, 
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
