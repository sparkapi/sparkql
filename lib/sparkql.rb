require 'sparkql/version'
require 'sparkql/token'
require 'sparkql/errors'
require 'sparkql/expression_resolver'
require 'sparkql/lexer'
require 'sparkql/parser_tools'
require 'sparkql/parser_compatibility'
require 'sparkql/parser'
require 'sparkql/semantic_analyzer'

# Parse
# SemanticAnalysis
# Intermediate Code Gen
# Literal Folding
# Custom Optimizations (Tree reordering)
module Sparkql
  FUNCTION_METADATA = YAML::load_file(File.join(__dir__, 'config/functions.yml'))
end
