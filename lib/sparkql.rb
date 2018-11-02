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
require 'sparkql/geo'

# Parse
# SemanticAnalysis
# Intermediate Code Gen
# Literal Folding
# Custom Optimizations (Tree reordering)
module Sparkql
  module V2
    def self.root
      File.dirname __dir__
    end

    def self.config
      File.join root, 'config'
    end
  end
end
require 'sparkql/semantic_analyzer'
