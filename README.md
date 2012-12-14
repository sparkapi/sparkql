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

