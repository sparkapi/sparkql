module Sparkql::Token
  SPACE = /[\t ]+/
  NEWLINE = /\r\n|\n\r|\r|\n/
  LPAREN = /\(/
  RPAREN = /\)/
  KEYWORD = /[A-Za-z]+/
  STANDARD_FIELD = /[A-Z]+[A-Za-z0-9]*/
  CUSTOM_FIELD = /^(\"([^$."][^."]+)\".\"([^$."][^."]*)\")/
  INTEGER = /^\-?[0-9]+/
  DECIMAL = /^\-?[0-9]+\.[0-9]+/
  CHARACTER = /^'([^'\\]*(\\.[^'\\]*)*)'/
  DATE = /^[0-9]{4}\-[0-9]{2}\-[0-9]{2}/
  DATETIME = /^[0-9]{4}\-[0-9]{2}\-[0-9]{2}T[0-9]{2}\:[0-9]{2}\:[0-9]{2}(\.[0-9]{1,6})?(((\+|-)[0-9]{2}:?[0-9]{2})|Z)?/
  BOOLEAN = /^true|false/
  NULL = /NULL|null|Null/
  # Reserved words
  RANGE_OPERATOR = 'Bt'
  EQUALITY_OPERATORS = ['Eq','Ne']
  OPERATORS = ['Gt','Ge','Lt','Le'] + EQUALITY_OPERATORS
  UNARY_CONJUNCTIONS = ['Not']
  CONJUNCTIONS = ['And','Or']

end
