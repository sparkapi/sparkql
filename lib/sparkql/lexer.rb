# frozen_string_literal: true

require 'strscan'

module SparkqlV2
  class Lexer < StringScanner
    include SparkqlV2::Token

    attr_reader :last_field, :current_token_value, :token_index

    def initialize(str)
      str.freeze
      super(str, false) # DO NOT dup str
    end

    def shift
      @token_index = pos

      token = if @current_token_value = scan(SPACE)
                [:SPACE, @current_token_value]
              elsif @current_token_value = scan(LPAREN)
                [:LPAREN, @current_token_value]
              elsif @current_token_value = scan(RPAREN)
                [:RPAREN, @current_token_value]
              elsif @current_token_value = scan(/\,/)
                [:COMMA, @current_token_value]
              elsif @current_token_value = scan(NULL)
                literal :NULL, 'NULL'
              elsif @current_token_value = scan(STANDARD_FIELD)
                check_standard_fields(@current_token_value)
              elsif @current_token_value = scan(DATETIME)
                literal :DATETIME, @current_token_value
              elsif @current_token_value = scan(DATE)
                literal :DATE, @current_token_value
              elsif @current_token_value = scan(TIME)
                literal :TIME, @current_token_value
              elsif @current_token_value = scan(DECIMAL)
                literal :DECIMAL, @current_token_value
              elsif @current_token_value = scan(INTEGER)
                literal :INTEGER, @current_token_value
              elsif @current_token_value = scan(CHARACTER)
                literal :CHARACTER, @current_token_value
              elsif @current_token_value = scan(BOOLEAN)
                literal :BOOLEAN, @current_token_value
              elsif @current_token_value = scan(KEYWORD)
                check_keywords(@current_token_value)
              elsif @current_token_value = scan(CUSTOM_FIELD)
                [:CUSTOM_FIELD, {
                  'name' => 'custom_field',
                  'value' => @current_token_value
                }]
              elsif eos?
                [false, false] # end of file, \Z don't work with StringScanner
              else
                [:UNKNOWN, "ERROR: '#{string}'"]
      end

      token.freeze
    end

    def check_reserved_words(value)
      u_value = value.capitalize
      if OPERATORS.include?(u_value)
        [:OPERATOR, u_value]
      elsif RANGE_OPERATOR == u_value
        [:RANGE_OPERATOR, u_value]
      elsif CONJUNCTIONS.include?(u_value)
        [:CONJUNCTION, u_value]
      elsif UNARY_CONJUNCTIONS.include?(u_value)
        [:UNARY_CONJUNCTION, u_value]
      else
        [:UNKNOWN, "ERROR: '#{string}'"]
      end
    end

    def check_standard_fields(value)
      result = check_reserved_words(value)
      if result.first == :UNKNOWN
        @last_field = value
        result = [:STANDARD_FIELD, { 'name' => 'field', 'value' => value }]
      end
      result
    end

    def check_keywords(value)
      result = check_reserved_words(value)
      result = [:KEYWORD, value] if result.first == :UNKNOWN
      result
    end

    def literal(symbol, value)
      type = symbol.to_s.downcase
      [symbol, {
        'name' => 'literal',
        'value' => escape_value(type, value),
        'type' => type
      }]
    end

    def escape_value(type, value)
      case type
      when 'character'
        return character_escape(value)
      when 'integer'
        return integer_escape(value)
      when 'decimal'
        return decimal_escape(value)
      when 'date'
        return date_escape(value)
      when 'datetime'
        return datetime_escape(value)
      when 'time'
        return time_escape(value)
      when 'boolean'
        return boolean_escape(value)
      when 'null'
        return nil
      end
      value
    end

    def character_escape(string)
      string.gsub(/^\'/, '').gsub(/\'$/, '').gsub(/\\'/, "'")
    end

    def integer_escape(string)
      string.to_i
    end

    def decimal_escape(string)
      string.to_f
    end

    def date_escape(string)
      Date.parse(string)
    end

    def datetime_escape(string)
      DateTime.parse(string)
    end

    def time_escape(string)
      DateTime.parse(string)
    end

    def boolean_escape(string)
      string == 'true'
    end
  end
end
