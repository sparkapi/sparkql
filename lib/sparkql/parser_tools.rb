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
  
  def tokenize_conjunction(exp1, conj, exp2)
    case conj
    when 'And'
      Sparkql::Nodes::And.new(exp1, exp2)
    when 'Or'
      Sparkql::Nodes::Or.new(exp1, exp2)
    when 'Not'
      Sparkql::Nodes::And.new(exp1, Sparkql::Nodes::Not.new(exp2))
    else
      raise "#{conj} is not supported"
    end
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
    
  def tokenize_group(expression)
    Sparkql::Nodes::Group.new(expression)
  end

  def tokenize_operator(field, operator, value)
    operator_class = case operator
    when 'Eq'
      Sparkql::Nodes::Equal
    when 'Gt'
      Sparkql::Nodes::GreaterThan
    when 'Ge'
      Sparkql::Nodes::GreaterThanOrEqualTo
    when 'Lt'
      Sparkql::Nodes::LessThan
    when 'Le'
      Sparkql::Nodes::LessThanOrEqualTo
    when 'Ne'
      Sparkql::Nodes::NotEqual
    when 'Bt'
      Sparkql::Nodes::Between
    else
      # TODO: Make cuter
      raise operator
    end

    operator_class.new(field, value)
  end

  # TODO Decide if this should use In logic instead of nested Ors
  # Make that shit configurable
  def tokenize_list_operator(field, operator, values)
    if values.size == 1
      tokenize_operator(field, operator, values.first)
    else
      new_values = values.map do |literal|
        tokenize_operator(field, operator, literal)
      end

      data = Sparkql::Nodes::Or.new(new_values.pop, new_values.pop)

      new_values.each do |val|
        data = Sparkql::Nodes::Or.new(data, val)
      end

      data
    end
  end

  def tokenize_function_args(lit1, lit2)
    array = lit1.kind_of?(Array) ? lit1 : [lit1]
    array << lit2
    array
  end
  
  def tokenize_field_arg(field)
    Sparkql::Nodes::Identifier.new(field)
  end
  
  def tokenize_function(name, f_args)
    Sparkql::Nodes::Function.new(name, f_args)
  end
  
  def on_error(error_token_id, error_value, value_stack)
    token_name = token_to_str(error_token_id)
    token_name.downcase!
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
