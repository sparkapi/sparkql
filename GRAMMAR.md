## SparkQL BNF Grammar
This document explains the rules for the Spark API filter language syntax and
is a living document generated from the reference implementation at 
https://github.com/sparkapi/sparkql.
### Precedence Rules
Unary minus is always tied to value, such as for negative numbers.


```
   prechigh
     nonassoc UMINUS
   preclow
```

### Grammar Rules
A filter (target) is a composition of filter basic filter expressions.


```
   rule
     target
       : expressions
       | /* none */ 
       ;
```

#### Expressions
One or more expressions


```
     expressions
       : expression
       | conjunction
       | unary_conjunction
       ;
```

#### Expression
The core of the filtering system, the expression requires a field, a condition 
and criteria for comparing the value of the field to the value(s) of the 
condition. The result of evaluating the expression on a resource is a true of 
false for matching the criteria.


```
     expression
       : field OPERATOR condition 
       | field RANGE_OPERATOR range 
       | group
       ;
```

#### Unary Conjunction
Some conjunctions don't need to expression at all times (e.g. 'NOT'). 


```
     unary_conjunction
       : UNARY_CONJUNCTION expression 
       ;  
```

#### Conjunction
Two expressions joined together using a supported conjunction


```
     conjunction
       : expressions CONJUNCTION expression 
       | expressions UNARY_CONJUNCTION expression 
       ;
```

#### Group
One or more expressions encased in parenthesis. There are limitations on nesting depth at the time of this writing.


```
     group
     	: LPAREN expressions RPAREN 
     	;
```

#### Field
Keyword for searching on, these fields should be discovered using the metadata 
rules. In general, Keywords that cannot be found will be dropped from the 
filter.


```
     field
     	: STANDARD_FIELD
     	| CUSTOM_FIELD
     	;
```

#### Condition
The determinant of the filter, this is typically a value or set of values of 
a type that the field supports (review the field meta data for support). 
Functions are also supported on some field types, and provide more flexibility
on filtering values


```
     condition
       : literal
       | function
       | literal_list 
       ;
```

#### Function
Functions may replace static values for conditions with supported field 
types. Functions may have parameters that match types supported by 
fields.


```
     function
       : function_name LPAREN RPAREN 
       | function_name LPAREN function_args RPAREN 
       ;
     function_name
       : KEYWORD
       ;
```

#### Function Arguments
Functions may optionally have a comma delimited list of parameters.


```
     function_args
       : function_arg
       | function_args COMMA function_arg 
       ; 
     function_arg
       : literal
       | literals
       ;
```

#### Literal List
A comma delimited list of functions and values.


```
     literal_list
       : literals
       | function
       | literal_list COMMA literals 
       | literal_list COMMA function 
       ;
```

#### Range List
A comma delimited list of values that support ranges for the Between operator 
(see rangeable).


```
     range                                                                             
       : rangeable COMMA rangeable 
       ;
```

#### Literals
Literals that support multiple values in a list for a condition


```
     literals
       : INTEGER
       | DECIMAL
       | CHARACTER
       ;
```

#### Literal
Literals only support a single value in a condition


```
     literal
       : DATE
       | DATETIME
       | BOOLEAN
       | NULL
       ;
```

#### Range List
Functions, and literals that can be used in a range                                                       


```
     rangeable
       : INTEGER
       | DECIMAL
       | DATE
       | DATETIME
       | function
       ;
```

