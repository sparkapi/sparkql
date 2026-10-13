SparkQL query language parser
=====================
This gem contains the syntax parser for processing spark api filter queries into manageable
expressions. To get an overview of the language syntax-wise, refer to the following files:

* lib/sparkql/parser.y   # BNF Grammar
* lib/sparkql/token.rb   # Token matching rules

Installation
-------------

Add the gem to your gemfile:

Gemfile
	gem 'sparkql', '~> 0.0.1'

When completed, run 'bundle install'.


Usage
-------------
Ruby 1.9 or greater is required.

See test/unit/parser_test.rb for generic parsing examples. In most cases an extended parser is
needed to do anything of significance, such as the postgres and db2 search implementations in the
API.

Here is a basic example:

	expressions = Parser.new.parse("Hello Eq 'World'")

The return value will be an array with one expression element containing the query information:

	{
	  :field => "Hello",
	  :type => :character,
	  :value => "'World'",
	  :operator => 'Eq'
	  # ...
	}

That flat list describes nesting through each expression's `:level`, `:block_group`,
`:conjunction`, and `:unary` keys, which can't express every filter's structure (e.g. the
middle group in `(A) And ((B) Or (C))`). When a consumer needs the real structure, use
`parse_tree`, which returns a syntax tree instead:

	tree = Parser.new.parse_tree("A Eq 1 Or B Eq 2 And C Eq 3")
	# { node: :conjunction, conjunction: "Or",
	#   left:  { node: :expression, expression: { field: "A", ... } },
	#   right: { node: :conjunction, conjunction: "And",
	#            left:  { node: :expression, expression: { field: "B", ... } },
	#            right: { node: :expression, expression: { field: "C", ... } } } }

Nodes are `:expression` (a comparison -- the same Hash `parse` returns), `:conjunction`
(`And`/`Or`/`Not`, where `Not` means "And Not"), `:unary` (`Not`), and `:group`
(parentheses). And/Not bind tighter than Or, as in SQL. `parse` is itself built by
flattening this tree, so the two always agree. See test/unit/parse_tree_test.rb.


Development
-------------
The parser is based on racc, a yacc like LR parser that is a part of the ruby runtime.  The grammar
is located at lib/sparkql/parser.y and is compiled as part of the test process.  Refer to the
Rakefile for details. When modifying the grammar, please checkin BOTH the parser.y and parser.rb
files.

Debugging grammar issues can be done by hand using the "racc" command. For example, a dump of the
parser states (and conflicts) can be generated via

	racc -o lib/sparkql/parser.rb lib/sparkql/parser.y -v  # see lib/sparkql/parser.output

The [rails/journey](https://github.com/rails/journey) project was an inspiration for this gem. Look it up on github for reference.

