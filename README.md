SparkQL parser
=====================
This gem contains the syntax parser for processing Spark Query Language filter queries into a manageable
structure. To get an overview of the language syntax-wise, refer to the following files:

* lib/sparkql/parser.y   # BNF Grammar
* lib/sparkql/token.rb   # Token matching rules

Installation
-------------

Add the gem to your gemfile:

Gemfile
	gem 'sparkql', '~> 2.0.0'

When completed, run 'bundle install'.


Usage
-------------

Parsing documentation can be found [here](docs/PARSING.md).
Semantic Analysis documentation can be found [here](docs/SEMANTIC_ANALYSIS.md).

Development
-------------
The parser is based on racc, a yacc like LR parser that is a part of the ruby runtime.  The grammar
is located at lib/sparkql/parser.y and is compiled as part of the test process.  Refer to the
Rakefile for details. When modifying the grammar, please checkin BOTH the parser.y and parser.rb
files.

Debugging grammar issues can be done by hand using the "racc" command. For example, a dump of the
parser states (and conflicts) can be generated via

	racc -o lib/sparkql/parser.rb lib/sparkql/parser.y -v  # see lib/sparkql/parser.output


