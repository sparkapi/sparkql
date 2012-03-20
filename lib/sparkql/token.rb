module Sparkql::Token
  SPACE = /[\t ]+/
  NEWLINE = /\r\n|\n\r|\r|\n/
  OPERATOR = /Eq|Ne|Gt|Ge|Lt|Le/
  CONJUNCTION = /And|Or/
  STANDARD_FIELD = /[A-Z]+[A-Za-z]*/
  INTEGER = /^\-?[0-9]+/
  DECIMAL = /^\-?[0-9]+\.[0-9]+/
  CHARACTER = /^'([^'\\]*(\\.[^'\\]*)*)'/
  DATE = /^[0-9]{4}\-[0-9]{2}\-[0-9]{2}/
  DATETIME = /^[0-9]{4}\-[0-9]{2}\-[0-9]{2}T[0-9]{2}\:[0-9]{2}\:[0-9]{2}\.[0-9]{6}/
  BOOLEAN = /^true|false/

end