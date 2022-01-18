# Required interface for existing parser implementations
module Sparkql::ParserCompatibility

  MAXIMUM_MULTIPLE_VALUES = 200
  MAXIMUM_EXPRESSIONS = 75
  MAXIMUM_LEVEL_DEPTH = 2
  MAXIMUM_FUNCTION_DEPTH = 5

  # Ordered by precedence.
  FILTER_VALUES = [
    {
      :type => :datetime,
      :operators => Sparkql::Token::OPERATORS + [Sparkql::Token::RANGE_OPERATOR]
    },
    {
      :type => :date,
      :operators => Sparkql::Token::OPERATORS + [Sparkql::Token::RANGE_OPERATOR]
    },
    {
      :type => :time,
      :operators => Sparkql::Token::OPERATORS + [Sparkql::Token::RANGE_OPERATOR]
    },
    {
      :type => :character,
      :multiple => /^'([^'\\]*(\\.[^'\\]*)*)'/,
      :operators => Sparkql::Token::EQUALITY_OPERATORS
    },
    {
      :type => :integer,
      :multiple => /^\-?[0-9]+/,
      :operators => Sparkql::Token::OPERATORS + [Sparkql::Token::RANGE_OPERATOR]
    },
    {
      :type => :decimal,
      :multiple => /^\-?[0-9]+\.[0-9]+/,
      :operators => Sparkql::Token::OPERATORS + [Sparkql::Token::RANGE_OPERATOR]
    },
    {
      :type => :shape,
      :operators => Sparkql::Token::EQUALITY_OPERATORS
    },
    {
      :type => :boolean,
      :operators => Sparkql::Token::EQUALITY_OPERATORS
    },
    {
      :type => :null,
      :operators => Sparkql::Token::EQUALITY_OPERATORS
    },
    {
      :type => :function,
      :operators => Sparkql::Token::OPERATORS + [Sparkql::Token::RANGE_OPERATOR]
    },
  ]

  OPERATORS_SUPPORTING_MULTIPLES = ["Eq","Ne"]

  # To be implemented by child class.
  # Shall return a valid query string for the respective database,
  # or nil if the source could not be processed.  It may be possible to return a valid
  # SQL string AND have errors ( as checked by errors? ), but this will be left
  # to the discretion of the child class.
  def compile( source, mapper )
   raise NotImplementedError
  end

  # Returns a list of expressions tokenized in the following format:
  # [{ :field => IdentifierName, :operator => "Eq", :value => "'Fargo'", :type => :character, :conjunction => "And" }]
  # This step will set errors if source is not syntactically correct.
  def tokenize( source )
    raise ArgumentError, "You must supply a source string to tokenize!" unless source.is_a?(String)

    # Reset the parser error stack
    @errors = []

    expressions = self.parse(source)
    expressions
  end

  # Returns an array of errors.  This is an array of ParserError objects
  def errors
    @errors = [] unless defined?(@errors)
    @errors
  end

  # Delegator for methods to process the error list.
  def process_errors
    Sparkql::ErrorsProcessor.new(errors)
  end

  # delegate :errors?, :fatal_errors?, :dropped_errors?, :recovered_errors?, :to => :process_errors
  # Since I don't have rails delegate...
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

  def escape_value_list( expression )
    final_list = []
    expression[:value].each do | value |
      new_exp = {
        :value => value,
        :type => expression[:type]
      }
      final_list << escape_value(new_exp)
    end
    expression[:value] = final_list
  end

  def escape_value( expression )
    if expression[:value].is_a? Array
      return escape_value_list( expression )
    end
    case expression[:type]
    when :character
      return character_escape(expression[:value])
    when :integer
      return integer_escape(expression[:value])
    when :decimal
      return decimal_escape(expression[:value])
    when :date
      return date_escape(expression[:value])
    when :datetime
      return datetime_escape(expression[:value])
    when :time
      return time_escape(expression[:value])
    when :boolean
      return boolean_escape(expression[:value])
    when :null
      return nil
    end
    expression[:value]
  end

  # processes escape characters for a given string.  May be overridden by
  # child classes.
  def character_escape( string )
    string.gsub(/^\'/,'').gsub(/\'$/,'').gsub(/\\'/, "'")
  end

  def integer_escape( string )
    string.to_i
  end

  def decimal_escape( string )
    string.to_f
  end

  def date_escape(string)
    Date.parse(string)
  end

  # DateTime may have timezone info. Given that, we should honor it it when
  # present or setting an appropriate default when not. Either way, we should
  # convert to local appropriate for the parser when we're done.
  def datetime_escape(string)
    unlocalized_datetime = DateTime.parse(string)
    unlocalized_datetime.new_offset(offset)
  end

  # Times don't have any timezone info. When parsing, pick the proper one to
  # set things at.
  def time_escape(string)
    DateTime.parse("#{string}#{offset}")
  end

  def boolean_escape(string)
    "true" == string
  end

  # Returns the rule hash for a given type
  def rules_for_type( type )
    FILTER_VALUES.each do |rule|
      return rule if rule[:type] == type
    end
    nil
  end

  # true if a given type supports multiple values
  def supports_multiple?( type )
    rules_for_type(type).include?( :multiple )
  end

  # Maximum supported nesting level for the parser filters
  def max_level_depth
    MAXIMUM_LEVEL_DEPTH
  end

  def max_expressions
    MAXIMUM_EXPRESSIONS
  end

  def max_values
    MAXIMUM_MULTIPLE_VALUES
  end

  def max_function_depth
    MAXIMUM_FUNCTION_DEPTH
  end

  private

  def tokenizer_error( error_hash )

    if @lexer
      error_hash[:token_index] = @lexer.token_index
    end

    self.errors << Sparkql::ParserError.new( error_hash )
  end
  alias :compile_error :tokenizer_error

  # Checks the type of an expression with what is expected.
  def check_type!(expression, expected, supports_nulls = true)
    if (expected == expression[:type] && !expression.key?(:field_manipulations)) ||
        (expression.key?(:field_manipulations) && check_function_type?(expression, expected)) ||
      (supports_nulls && expression[:type] == :null)
      return true
    # If the field will be passed into a function,
    # check the type of the return value of the function
    # and coerce if necessary.
    elsif expression[:field_manipulations] &&
          expression[:type] == :integer &&
          expression[:field_manipulations][:return_type] == :decimal
      expression[:type] = :decimal
      expression[:cast] = :integer
      return true
    elsif expected == :datetime && expression[:type] == :date
      expression[:type] = :datetime
      expression[:cast] = :date
      return true
    elsif expected == :date && expression[:type] == :datetime
      expression[:type] = :date
      expression[:cast] = :datetime
      if multiple_values?(expression[:value])
        expression[:value].map!{ |val| coerce_datetime val }
      else
        expression[:value] = coerce_datetime expression[:value]
      end
      return true
    elsif expected == :decimal && expression[:type] == :integer
      expression[:type] = :decimal
      expression[:cast] = :integer
      return true
    end
    type_error(expression, expected)
    false
  end

  def type_error( expression, expected )
      compile_error(:token => expression[:field], :expression => expression,
            :message => "expected #{expected} but found #{expression[:type]}",
            :status => :fatal )
  end

  # If a function is being applied to a field, we check that the return type of
  # the function matches what is expected, and that the function supports the
  # field type as the first argument.
  def check_function_type?(expression, expected)
    validate_manipulation_types(expression[:field_manipulations], expected)
  end

  def validate_manipulation_types(field_manipulations, expected)
    if field_manipulations[:type] == :function
      return false unless supported_function?(field_manipulations[:function_name])

      function = lookup_function(field_manipulations[:function_name])
      field_manipulations[:args].each_with_index do |arg, index|
        if arg[:type] == :field
          return false unless function[:args][index].include?(:field)
        end
      end
    elsif field_manipulations[:type] == :arithmetic
      lhs = field_manipulations[:lhs]
      return false unless validate_side(lhs, expected)

      rhs = field_manipulations[:rhs]
      return false unless rhs.nil? || validate_side(rhs, expected)
    end
    true
  end

  def validate_side(side, expected)
    if side[:type] == :arithmetic
      return validate_manipulation_types(side, expected)
    elsif side[:type] == :field
      return false unless [:decimal, :integer].include?(expected)
    elsif side[:type] == :function
      return false unless [:decimal, :integer].include?(side[:return_type])
    elsif ![:decimal, :integer].include?(side[:type])
      return false
    end
    true
  end

  # Builds the correct operator based on the type and the value.
  # default should be the operator provided in the actual filter string
  def get_operator(expression, default )
    f = rules_for_type(expression[:type])
    if f[:operators].include?(default)
      if f[:multiple] && range?(expression[:value]) && default == 'Bt'
        return "Bt"
      elsif f[:multiple] && multiple_values?(expression[:value])
        return nil unless operator_supports_multiples?(default)
        return default == "Ne" ? "Not In" : "In"
      elsif default == "Ne"
        return "Not Eq"
      end
      return default
    else
      return nil
    end
  end

  def multiple_values?(value)
    Array(value).size > 1
  end

  def range?(value)
    Array(value).size == 2
  end

  def operator_supports_multiples?(operator)
    OPERATORS_SUPPORTING_MULTIPLES.include?(operator)
  end

  # Datetime coercion to date factors in the current time zone when selecting a
  # date.
  def coerce_datetime datetime_string
    if datetime_string.match(/^(\d{4}-\d{2}-\d{2})$/)
      datetime_string
    elsif datetime_string.match(/^(\d{4}-\d{2}-\d{2})/)
      datetime = datetime_escape(datetime_string)
      datetime.strftime(Sparkql::FunctionResolver::STRFTIME_DATE_FORMAT)
    else
      datetime_string
    end
  end
end
