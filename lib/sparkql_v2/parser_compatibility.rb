# frozen_string_literal: true

module SparkqlV2
  # Required interface for existing parser implementations
  module ParserCompatibility
    MAXIMUM_MULTIPLE_VALUES = 200
    MAXIMUM_EXPRESSIONS = 75
    TOKENIZE_STRING_REQ = 'You must supply a source string to tokenize!'.freeze

    # To be implemented by child class.
    # Shall return a valid query string for the respective database,
    # or nil if the source could not be processed.  It may be possible to
    # return a valid SQL string AND have errors ( as checked by errors? ),
    # but this will be left to the discretion of the child class.
    def compile(_source, _mapper)
      raise NotImplementedError
    end

    # Returns a list of expressions tokenized in the following format:
    # This step will set errors if source is not syntactically correct.
    def tokenize(source)
      raise ArgumentError, TOKENIZE_STRING_REQ unless source.is_a?(String)

      # Reset the parser error stack
      @errors = []

      expressions = parse(source)
      expressions
    end

    # Returns an array of errors.  This is an array of ParserError objects
    def errors
      @errors = [] unless defined?(@errors)
      @errors
    end

    # Delegator for methods to process the error list.
    def process_errors
      SparkqlV2::ErrorsProcessor.new(@errors)
    end

    # delegation since we don't have rails delegate
    def errors?
      process_errors.errors?
    end

    def fatal_errors?
      process_errors.fatal_errors?
    end

    def dropped_errors?
      process_errors.dropped_errors?
    end

    def recovered_errors?
      process_errors.recovered_errors?
    end

    def max_expressions
      MAXIMUM_EXPRESSIONS
    end

    def max_values
      MAXIMUM_MULTIPLE_VALUES
    end

    private

    def tokenizer_error(error_hash)
      error_hash[:token_index] = @lexer.token_index if @lexer

      errors << SparkqlV2::ParserError.new(error_hash)
    end
    alias compile_error tokenizer_error
  end
end
