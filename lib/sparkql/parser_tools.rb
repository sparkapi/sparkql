# This is the guts of the parser internals and is mixed into the parser for organization.
module Sparkql::ParserTools
  
  def parse(str)
    @lexer = Sparkql::Lexer.new(str)
    results = do_parse
    max = Sparkql::ParserCompatibility::MAXIMUM_EXPRESSIONS
    return if results.nil?
    results.size > max ? results[0,max] : results
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
    if @lexer.level > max_level_depth
      compile_error(:token => "(", :expression => expression,
            :message => "You have exceeded the maximum nesting level.  Please nest no more than #{max_level_depth} levels deep.",
            :status => :fatal, :syntax => false )
    end
    if operator.nil?
      tokenizer_error(:token => op, :expression => expression,
        :message => "Operator not supported for this type and value string", :status => :fatal )
    end
    [expression]
  end

  def tokenize_conjunction(exp1, conj, exp2)
    exp2.first[:conjunction] = conj
    exp1 + exp2
  end
  
  def tokenize_group(expressions)
    @lexer.leveldown
    expressions
  end

  def tokenize_multiple(lit1, lit2)
    if lit1[:type] != lit2[:type]
      tokenizer_error(:token => @lexer.last_field, 
                      :message => "Type mismatch in field list.",
                      :status => :fatal, 
                      :syntax => true)    
    end
    array = Array(lit1[:value])
    unless array.size >= Sparkql::ParserCompatibility::MAXIMUM_MULTIPLE_VALUES
      array << lit2[:value]
    end
    {
      :type => lit1[:type],
      :value => array,
      :multiple => "true" # TODO ?
    }
  end
  
  def tokenize_function(name, f_args)
    args = f_args.instance_of?(Array) ? f_args : [f_args]
    args.each do |arg|
      arg[:value] = escape_value(arg)
    end
    resolver = Sparkql::FunctionResolver.new(name, args)
    
    resolver.validate
    if(resolver.errors?)
      errors += resolver.errors
      return nil
    else
      return resolver.call()
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

end
