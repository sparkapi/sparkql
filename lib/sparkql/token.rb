module Sparkql::Token
  SPACE = /[\t ]+/.freeze
  NEWLINE = /\r\n|\n\r|\r|\n/.freeze
  LPAREN = /\(/.freeze
  RPAREN = /\)/.freeze
  KEYWORD = /[A-Za-z]+/.freeze

  ADD = 'Add'.freeze
  SUB = 'Sub'.freeze

  MUL = 'Mul'.freeze
  DIV = 'Div'.freeze
  MOD = 'Mod'.freeze

  STANDARD_FIELD = /[A-Z]+[A-Za-z0-9]*/.freeze
  CUSTOM_FIELD = /^("([^$."][^."]+)"."([^$."][^."]*)")/.freeze
  INTEGER = /^-?[0-9]+/.freeze
  DECIMAL = /^-?[0-9]+\.[0-9]+([Ee]-?[0-9]{1,2})?/.freeze
  CHARACTER = /^'([^'\\]*(\\.[^'\\]*)*)'/.freeze
  DATE = /^[0-9]{4}-[0-9]{2}-[0-9]{2}/.freeze
  TIME = /^[0-9]{2}:[0-9]{2}((:[0-9]{2})(\.[0-9]{1,50})?)?/.freeze
  DATETIME = /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}((:[0-9]{2})(\.[0-9]{1,50})?)?(((\+|-)[0-9]{2}:?[0-9]{2})|Z)?/.freeze
  BOOLEAN = /^true|false/.freeze
  NULL = /NULL|null|Null/.freeze
  # Reserved words
  RANGE_OPERATOR = 'Bt'.freeze
  EQUALITY_OPERATORS = %w[Eq Ne].freeze
  OPERATORS = %w[Gt Ge Lt Le] + EQUALITY_OPERATORS
  UNARY_CONJUNCTIONS = ['Not'].freeze
  CONJUNCTIONS = %w[And Or].freeze
end
