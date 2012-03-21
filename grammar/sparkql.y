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
    ;
    
  expression
    : field OPERATOR condition { result = tokenize_expression(val[0], val[1],val[2]) }
    | group
    ;
  
  conjunction
    : expressions CONJUNCTION expression { result = tokenize_conjunction(val[0], val[1],val[2]) }
    ;
  
  group
  	: LPAREN expressions RPAREN { result = tokenize_group(val[1]) }
  	;

  field
  	: STANDARD_FIELD
  	;
  
  condition
    : literal
    | literal_list
    ;
  
  literal_list
    : literals
    | literal_list COMMA literals { result = tokenize_multiple(val[0], val[2]) }
    ;
    
  # Literals that support multiple
  literals
    : INTEGER
    | DECIMAL
    | CHARACTER
    ;
  
  # Literals that support single only
  literal
    : DATE
    | DATETIME
    | BOOLEAN
    ;
    
end

---- header
# $Id$
---- inner
  include Sparkql::ParserTools
  include Sparkql::ParserCompatibility
  
  attr_accessor :configuration
  
---- footer

# END PARSER
