# frozen_string_literal: true

module Sparkql
  module V2
    module Token
      SPACE = /[\t ]+/
      NEWLINE = /\r\n|\n\r|\r|\n/
      LPAREN = /\(/
      RPAREN = /\)/
      KEYWORD = /[A-Za-z]+/
      STANDARD_FIELD = /[A-Z]+[A-Za-z0-9]*/
      CUSTOM_FIELD = /^(\"([^$."][^."]+)\".\"([^$."][^."]*)\")/
      INTEGER = /^\-?[0-9]+/
      DECIMAL = /^\-?[0-9]+\.[0-9]+([Ee]-?[0-9]{1,2})?/
      CHARACTER = /^'([^'\\]*(\\.[^'\\]*)*)'/
      DATE = /^[0-9]{4}\-[0-9]{2}\-[0-9]{2}/
      TIME = /^[0-9]{2}\:[0-9]{2}((\:[0-9]{2})(\.[0-9]{1,50})?)?/
      DATETIME = /^[0-9]{4}\-[0-9]{2}\-[0-9]{2}T[0-9]{2}\:[0-9]{2}
        ((\:[0-9]{2})(\.[0-9]{1,50})?)?
        (((\+|-)[0-9]{2}\:?[0-9]{2})|Z)?/x
      BOOLEAN = /^true|false/
      NULL = /NULL|null|Null/
      # Reserved words
      RANGE_OPERATOR = 'Bt'.freeze
      EQUALITY_OPERATORS = ['Eq', 'Ne'].freeze
      OPERATORS = ['Gt', 'Ge', 'Lt', 'Le'] + EQUALITY_OPERATORS
      UNARY_CONJUNCTIONS = ['Not'].freeze
      CONJUNCTIONS = ['And', 'Or'].freeze
    end
  end
end
