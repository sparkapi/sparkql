# Semantic Analysis

After parsing, we need to make sure we are dealing with proper type comparisons and that function parameters are accurate. To do this we use the SemanticAnalyzer. When successful it has nearly the same output as the Parser, but with more data.

## New Attributes

The `:field` and `:custom_field` nodes will gain a new `:type` attribute which is the label for the type of that field. `:type` may also have the value `:drop` which signifies that the field was not searcable.

## New Nodes

Following are new node(s) which will be added the the parse tree:

name | description | lhs | rhs
---- | ----------- | --- | ---
`:coercion` | Specifies what we will need to coerce a value to. Same as the `:cast` function, but is done without user explicitness and the `:function` attribute is not set. | the expression to coerce | the type as a symbol to coerce to.

