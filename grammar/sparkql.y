# $Id$
#
# SparkQL grammar

class Sparkql::Parser
  prechigh
    nonassoc UMINUS
  preclow
rule
  target
    : expressions
    | /* none */ { result = 0 }
    ;

  expressions
    : expression
    | conjunction
    | group
    ;
    
  expression
    : field OPERATOR condition { result = tokenize_expression(val[0], val[1],val[2]) }
    ;
  
  conjunction
    : expressions CONJUNCTION expressions { result = tokenize_conjunction(val[0], val[1],val[2]) }
    ;
  
  group
  	: LPAREN expressions RPAREN { result = tokenize_group(val[1]) }
  	;

  field
  	: STANDARD_FIELD
  	; 
  
  condition
    : literal
    ;
    
  literal
    : INTEGER
    | DECIMAL
    | CHARACTER
    | DATE
    | DATETIME
    | BOOLEAN
    ;
    
end

---- header
# $Id$
---- inner
  
  def parse(str)
    @lexer = Sparkql::Lexer.new(str)
    do_parse
  end

  def next_token
    t = @lexer.shift
	while t[0] == :SPACE or t[0] == :NEWLINE
	  t = @lexer.shift
	end
	t
  end
  
  def tokenize_expression(field, op, val)
    expression = {:field => field, :operator => op, :value => val, :conjunction => 'And', :level => @lexer.level, :block_group => @lexer.block_group_identifier }
    puts "TOKEN: #{expression.inspect}"
    expression
  end

  def tokenize_conjunction(exp1, conj, exp2)
    exp2[:conjunction] = conj
    puts "tokenize_conjunction: #{conj.inspect}"
    [exp1, exp2]
  end
  
  def tokenize_group(expressions)
    puts "tokenize_group: #{expressions.inspect}"
    expressions
  end
  
  
  def on_error(error_token_id, error_value, value_stack)
    puts "ERROR #{error_token_id} - #{error_value} - #{value_stack}"
    token_name = token_to_str(error_token_id)
    token_name.downcase!
    token = error_value.to_s.inspect
    str = 'parse error on '
    str << token_name << ' ' unless token_name == token
    str << token
    @lexer.error(str)
  end  

---- footer

# END PARSER
