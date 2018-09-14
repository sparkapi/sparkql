# Parsing
So, you want to parse some sparkql? Well, you are in the right place.

## Usage

Here is a basic example:

```
ast = Sparkql::Parser.new.parse("Hello Eq 'World'")
```

The return value will be the abstract syntax tree containing the query information.

```ruby
{
  :name => :eq,
  :lhs => {
    :name => :field,
    :value => "Hello"
  },
  :rhs => {
    :name => :literal,
    :value => "World",
    :type => :character
  }
}
```

Alternatively you can check if there was invalid syntax by checking errors on the parser object.

```ruby
parser = Sparkql::Parser.new
parser.parse("Hello Eq world")

parser.errors? # true
parser.errors # Array of error values
```

## Base Nodes

name | description | value | type
---- | ----------- | ----- | ----
`:literal` | A literal value. | Ruby representation of the literal.| name of literal|
`:field` | Identifier used for most fields. | String representation of the identifier.| `:field` |
`:custom_field` | Identifier used for custom fields. | String representation of the identifier.| `:field` |

## Conjunctions
name | description | lhs | rhs
---- | ----------- | --- | ---
`:and` | True if left and right results in true | left expression | right expression
`:or` | True if left or right results in true | left expression | right expression

## Operators
name | description | lhs | rhs
---- | ----------- | --- | ---
`:eq` | check equality. | left hand expression | right hand expression
`:ne` | check inequality. | left hand expression | right hand expression
`:in` | check mass equality. rhs is any number of expressions to check against. | left hand expression | [right hand expressions]
`:gt` | greater than. | left hand expression | right hand expression
`:ge` | greater than or equal to. | left hand expression| right hand expression
`:lt` | less than. | left hand expression| right hand expression
`:le` | less than or equal to. | left hand expression| right hand expression
`:bt` | between. rhs is an array with 2 expressions to check between. | left hand expression| [right hand expressions]


## Single Value Operators
name | description | value
---- | ----------- | -----
`:group` | A parenthesis wrapped expression. | Nested expression with precedence.
`:unary_not` | Unary not. | Expression to negate.

## Functions

Parsing will also yield function nodes which are documented in [FUNCTIONS.md](docs/FUNCTIONS.md).
