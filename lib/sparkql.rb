# frozen_string_literal: true

require 'yaml'
require 'sparkql/version'
require 'sparkql/token'
require 'sparkql/errors'
require 'sparkql/expression_resolver'
require 'sparkql/lexer'
require 'sparkql/parser_tools'
require 'sparkql/parser_compatibility'
require 'sparkql/parser'
require 'sparkql/semantic_analyzer'
require 'sparkql/geo'

# Parse
# SemanticAnalysis
# Intermediate Code Gen
# Literal Folding
# Custom Optimizations (Tree reordering)
module Sparkql
  FUNCTION_FILE = 'config/functions.yml'.freeze
  FUNCTION_METADATA = YAML.load_file(File.join(__dir__, FUNCTION_FILE))
end
