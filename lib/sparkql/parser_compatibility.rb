# Required interface for existing parser implementations
module Sparkql::ParserCompatibility
  
  MAXIMUM_MULTIPLE_VALUES = 25
  MAXIMUM_EXPRESSIONS = 50
  MAXIMUM_LEVEL_DEPTH = 2
  
  # TODO I Really don't think this is required anymore
  # Ordered by precedence.
  FILTER_VALUES = [
    {
      :type => :datetime,
      :regex => /^[0-9]{4}\-[0-9]{2}\-[0-9]{2}T[0-9]{2}\:[0-9]{2}\:[0-9]{2}\.[0-9]{6}$/,
      :operators => Sparkql::Token::OPERATORS + [Sparkql::Token::RANGE_OPERATOR]
    },
    {
      :type => :date,
      :regex => /^[0-9]{4}\-[0-9]{2}\-[0-9]{2}$/,
      :operators => Sparkql::Token::OPERATORS + [Sparkql::Token::RANGE_OPERATOR]
    },
    {
      :type => :character,
      :regex => /^'([^'\\]*(\\.[^'\\]*)*)'$/, # Strings must be single quoted.  Any inside single quotes must be escaped.
      :multiple => /^'([^'\\]*(\\.[^'\\]*)*)'/,
      :operators => Sparkql::Token::EQUALITY_OPERATORS
    },
    {
      :type => :integer,
      :regex => /^\-?[0-9]+$/,
      :multiple => /^\-?[0-9]+/,
      :operators => Sparkql::Token::OPERATORS + [Sparkql::Token::RANGE_OPERATOR]
    },
    {
      :type => :decimal,
      :regex => /^\-?[0-9]+\.[0-9]+$/,
      :multiple => /^\-?[0-9]+\.[0-9]+/,
      :operators => Sparkql::Token::OPERATORS + [Sparkql::Token::RANGE_OPERATOR]
    },
    {
      :type => :shape,
      # This type is not parseable, so no regex
      :operators => Sparkql::Token::EQUALITY_OPERATORS
    },
    {
      :type => :boolean,
      :regex => /^true|false$/,
      :operators => Sparkql::Token::EQUALITY_OPERATORS
    },
    {
      :type => :null,
      :regex => /^NULL|Null|null$/,
      :operators => Sparkql::Token::EQUALITY_OPERATORS
    }
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
    Sparkql::ErrorsProcessor.new(@errors)
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

  def datetime_escape(string)
    DateTime.parse(string)
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
  
  private
  
  def tokenizer_error( error_hash )
    self.errors << Sparkql::ParserError.new( error_hash )
  end
  alias :compile_error :tokenizer_error
  
  # Checks the type of an expression with what is expected.
  def check_type!(expression, expected, supports_nulls = true)
    if expected == expression[:type] || (supports_nulls && expression[:type] == :null)
      return true
    elsif expected == :datetime &&  expression[:type] == :date
      expression[:type] = :datetime
      expression[:cast] = :date
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
  
end
