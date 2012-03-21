# This is the guts of the parser internals and is mixed into the parser for organization.
module Sparkql::ParserTools
  
  def parse(str)
    @lexer = Sparkql::Lexer.new(str,self)
    results = do_parse
    
    puts "Result #{results.inspect}"
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
    expression = val.merge({:field => field, :operator => get_operator(val,op), :conjunction => 'And', 
      :level => @lexer.level, :block_group => @lexer.block_group_identifier})
      
    #puts "TOKEN: #{expression.inspect}"
    [expression]
  end

  def tokenize_conjunction(exp1, conj, exp2)
    exp2.first[:conjunction] = conj
    puts "tokenize_conjunction: #{conj.inspect}"
    exp1 + exp2
  end
  
  def tokenize_group(expressions)
    puts "tokenize_group: #{expressions.inspect}"
    expressions
  end

  def tokenize_multiple(lit1, lit2)
    if lit1[:type] != lit2[:type]
      tokenizer_error(:token => @lexer.last_field, :message => "Type mismatch in field list.") 
    end
    array = Array(lit1[:value])
    unless array.size > Sparkql::ParserCompatibility::MAXIMUM_MULTIPLE_VALUES
      array << lit2[:value]
    end
    puts "tokenize_multiple: #{array.inspect}"
    {
      :type => lit1[:type],
      :value => array,
      :multiple => "true" # TODO 
    }
  end
  
  def on_error(error_token_id, error_value, value_stack)
    puts "ERROR #{error_token_id} - #{error_value} - #{value_stack}"
    token_name = token_to_str(error_token_id)
    token_name.downcase!
    token = error_value.to_s.inspect
    tokenizer_error(:token => @lexer.last_field, :message => "Error parsing token #{token_name}")    
    
    str = 'parse error on '
    str << token_name << ' ' unless token_name == token
    str << token
    @lexer.error(str)
  end  

end
