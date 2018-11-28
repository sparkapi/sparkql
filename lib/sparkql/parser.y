# $Id$
#
# SparkQL grammar

class Sparkql::Parser

###############################################################################
# READ THIS!
# The grammar documentation is parsed from this file and is in a sensitive
# syntax between the START_MARKDOWN and STOP_MARKDOWN keywords. In general, all
# line comments will be treated as markdown text, and everything else is padded
# for code formatting
###############################################################################

#START_MARKDOWN

### SparkQL BNF Grammar
#
# This document explains the rules for the Spark API filter language syntax and
# is a living document generated from the reference implementation at
# https://github.com/sparkapi/sparkql.

#### Precedence Rules
#
# Unless otherwise specified, SparkQL follows SQL precendence conventions for
# operators and conjunctions.
#
# Unary minus is always tied to value, such as for negative numbers.
prechigh
  nonassoc UMINUS
  left MUL DIV MOD
  left ADD SUB
preclow


#### Grammar Rules
#
# A filter (target) is a composition of filter basic filter expressions.
rule
  target
    : expressions
    | /* none */ { result = 0 }
    ;

##### Expressions
#
# One or more expressions
  expressions
    : expression
    | conjunction
    | unary_conjunction
    ;

##### Expression
#
# The core of the filtering system, the expression requires a field, a condition
# and criteria for comparing the value of the field to the value(s) of the
# condition. The result of evaluating the expression on a resource is a true of
# false for matching the criteria. We are separating functions and arithmetic
# based on if we are acting on the field side or the literal side. This is to
# allow literal folding on the literal side.
  expression
    : field_expression OPERATOR condition { result = tokenize_expression(val[0], val[1],val[2]) }
    | field_expression RANGE_OPERATOR range { result = tokenize_expression(val[0], val[1], val[2]) }
    | group
    ;

##### Unary Conjunction
#
# Some conjunctions don't need to expression at all times (e.g. 'NOT').
  unary_conjunction
    : UNARY_CONJUNCTION expression { result = tokenize_unary_conjunction(val[0], val[1]) }
    ;

##### Conjunction
#
# Two expressions joined together using a supported conjunction
  conjunction
    : expressions CONJUNCTION expression { result = tokenize_conjunction(val[0], val[1],val[2]) }
    | expressions UNARY_CONJUNCTION expression { result = tokenize_conjunction(val[0], val[1],val[2]) }
    ;

##### Group
#
# One or more expressions encased in parenthesis. There are limitations on nesting depth at the time of this writing.

  group
    : LPAREN expressions RPAREN { result = tokenize_group(val[1]) }
    ;

  field_expression
    : field_arithmetic_expression
    ;

  field_arithmetic_expression
    : field_arithmetic_expression ADD field_arithmetic_expression { result = tokenize_arithmetic(val[0], val[1], val[2]) }
    | field_arithmetic_expression SUB field_arithmetic_expression { result = tokenize_arithmetic(val[0], val[1], val[2]) }
    | field_arithmetic_expression MUL field_arithmetic_expression { result = tokenize_arithmetic(val[0], val[1], val[2]) }
    | field_arithmetic_expression DIV field_arithmetic_expression { result = tokenize_arithmetic(val[0], val[1], val[2]) }
    | field_arithmetic_expression MOD field_arithmetic_expression { result = tokenize_arithmetic(val[0], val[1], val[2]) }
    | literals
    | field_function_expression
    ;

  field_function_expression
    : field
    | function
    ;

##### Condition
#
# The determinant of the filter, this is typically a value or set of values of
# a type that the field supports (review the field meta data for support).
# Functions are also supported on some field types, and provide more flexibility
# on filtering values
  condition
    : arithmetic_condition
    | literal_list { result = tokenize_list(val[0]) }
    | literal
    ;

  arithmetic_condition
    : condition ADD condition { result = add_fold(val[0], val[2]) }
    | condition SUB condition { result = sub_fold(val[0], val[2]) }
    | condition MUL condition { result = mul_fold(val[0], val[2]) }
    | condition DIV condition { result = div_fold(val[0], val[2]) }
    | condition MOD condition { result = mod_fold(val[0], val[2]) }

##### Function
#
# Functions may replace static values for conditions with supported field
# types. Functions may have parameters that match types supported by
# fields.
  function
    : function_name LPAREN RPAREN { result = tokenize_function(val[0], []) }
    | function_name LPAREN function_args RPAREN { result = tokenize_function(val[0], val[2]) }
    ;

  literal_function
    : function_name LPAREN RPAREN { result = tokenize_function(val[0], []) }
    | function_name LPAREN literal_function_args RPAREN { result = tokenize_function(val[0], val[2]) }
    ;

  function_name
    : KEYWORD
    ;

##### Function Arguments
#
# Functions may optionally have a comma delimited list of parameters.
  function_args
    : function_arg
    | function_args COMMA function_arg { result = tokenize_function_args(val[0], val[2]) }
    ;

  function_arg
    : field_function_expression { result = tokenize_field_arg(val[0]) }
    | literal
    | literals
    ;

  literal_function_args
    : literal_function_arg
    | literal_function_args COMMA literal_function_arg { result = tokenize_function_args(val[0], val[2]) }
    ;

  literal_function_arg
    : literal
    | literals
    ;

##### Literal List
#
# A comma delimited list of functions and values.
  literal_list
    : literals
    | literal_function
    | literal_list COMMA literals { result = tokenize_multiple(val[0], val[2]) }
    | literal_list COMMA function { result = tokenize_multiple(val[0], val[2]) }
    ;

##### Range List
#
# A comma delimited list of values that support ranges for the Between operator
# (see rangeable).
  range
    : rangeable COMMA rangeable { result = tokenize_multiple(val[0], val[2]) }
    ;

##### Literals
#
# Literals that support multiple values in a list for a condition
  literals
    : INTEGER
    | DECIMAL
    | CHARACTER
    | LPAREN literals RPAREN { result = val[1] }
    | UMINUS literals { result = tokenize_literal_negation(val[1]) }
    ;

##### Literal
#
# Literals only support a single value in a condition
  literal
    : DATE
    | DATETIME
    | TIME
    | BOOLEAN
    | NULL
    ;

##### Range List
#
# Functions, and literals that can be used in a range
  rangeable
    : INTEGER
    | DECIMAL
    | DATE
    | DATETIME
    | TIME
    | function
    ;

##### Field
#
# Keyword for searching on, these fields should be discovered using the metadata
# rules. In general, Keywords that cannot be found will be dropped from the
# filter.
  field
    : STANDARD_FIELD
    | CUSTOM_FIELD
    ;

#STOP_MARKDOWN


end

---- header
# $Id$
---- inner
  include Sparkql::ParserTools
  include Sparkql::ParserCompatibility

---- footer

# END PARSER
