# frozen_string_literal: true

require 'yaml'
require 'sparkql_v2/version'
require 'sparkql_v2/token'
require 'sparkql_v2/errors'
require 'sparkql_v2/expression_resolver'
require 'sparkql_v2/lexer'
require 'sparkql_v2/parser_tools'
require 'sparkql_v2/parser_compatibility'
require 'sparkql_v2/parser'
require 'sparkql_v2/geo'

# Parse
# SemanticAnalysis
# Intermediate Code Gen
# Literal Folding
# Custom Optimizations (Tree reordering)
module SparkqlV2
  def self.root
    File.dirname __dir__
  end

  def self.config
    File.join root, 'config'
  end
end
require 'sparkql_v2/semantic_analyzer'
