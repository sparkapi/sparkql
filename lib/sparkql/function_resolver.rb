require 'time' 
require 'geo_ruby'
require 'geo_ruby/ewk'
require 'sparkql/geo'

# Binding class to all supported function calls in the parser. Current support requires that the 
# resolution of function calls to happen on the fly at parsing time at which point a value and 
# value type is required, just as literals would be returned to the expression tokenization level.
#
# Name and argument requirements for the function should match the function declaration in 
# SUPPORTED_FUNCTIONS which will run validation on the function syntax prior to execution.
class Sparkql::FunctionResolver
  SECONDS_IN_DAY = 60 * 60 * 24
  STRFTIME_DATE_FORMAT = '%Y-%m-%d'
  STRFTIME_TIME_FORMAT = '%H:%M:%S.%N'
  VALID_REGEX_FLAGS = ["", "i"]
  MIN_DATE_TIME = Time.new(1970, 1, 1, 0, 0, 0, "+00:00").iso8601
  MAX_DATE_TIME = Time.new(9999, 12, 31, 23, 59, 59, "+00:00").iso8601
  VALID_CAST_TYPES = [:field, :character, :decimal, :integer]

  SUPPORTED_FUNCTIONS = {
    :polygon => {
      :args => [:character],
      :return_type => :shape
    }, 
    :rectangle => {
      :args => [:character],
      :return_type => :shape
    }, 
    :radius => {
      :args => [:character, [:decimal, :integer]],
      :return_type => :shape
    },
    :regex => {
      :args => [:character],
      :opt_args => [{
        :type => :character,
        :default => ''
      }],
      :return_type => :character
    },
    :substring => {
      :args => [[:field, :character], :integer],
      :opt_args => [{
        :type => :integer
      }],
      :resolve_for_type => true,
      :return_type => :character
    },
    :trim => {
      :args => [[:field, :character]],
      :resolve_for_type => true,
      :return_type => :character
    },
    :tolower => {
      :args => [[:field, :character]],
      :resolve_for_type => true,
      :return_type => :character
    },
    :toupper => {
      :args => [[:field, :character]],
      :resolve_for_type => true,
      :return_type => :character
    },
    :length => {
      :args => [[:field, :character]],
      :resolve_for_type => true,
      :return_type => :integer
    },
    :indexof => {
      :args => [[:field, :character], :character],
      :return_type => :integer
    },
    :concat => {
      :args => [[:field, :character], :character],
      :resolve_for_type => true,
      :return_type => :character
    },
    :cast => {
      :args => [[:field, :character, :decimal, :integer, :null], :character],
      :resolve_for_type => true,
    },
    :round => {
      :args => [[:field, :decimal]],
      :resolve_for_type => true,
      :return_type => :integer
    },
    :ceiling => {
      :args => [[:field, :decimal]],
      :resolve_for_type => true,
      :return_type => :integer
    },
    :floor => {
      :args => [[:field, :decimal]],
      :resolve_for_type => true,
      :return_type => :integer
    },
    :startswith => {
      :args => [:character],
      :return_type => :startswith
    },
    :endswith => {
      :args => [:character],
      :return_type => :endswith
    },
    :contains => {
      :args => [:character],
      :return_type => :contains
    },
    :linestring => {
      :args => [:character],
      :return_type => :shape
    },
    :days => {
      :args => [:integer],
      :return_type => :datetime
    },
    :months => {
      :args => [:integer],
      :return_type => :datetime
    },
    :years => {
      :args => [:integer],
      :return_type => :datetime
    },
    :now => {
      :args => [],
      :return_type => :datetime
    },
    :maxdatetime => {
      :args => [],
      :return_type => :datetime
    },
    :mindatetime => {
      :args => [],
      :return_type => :datetime
    },
    :date => { 
      :args => [[:field,:datetime,:date]],
      :resolve_for_type => true,
      :return_type => :date
    },
    :time => { 
      :args => [[:field,:datetime,:date]],
      :resolve_for_type => true,
      :return_type => :time
    },
    :year => { 
      :args => [[:field,:datetime,:date]],
      :resolve_for_type => true,
      :return_type => :integer
    },
    :month => { 
      :args => [[:field,:datetime,:date]],
      :resolve_for_type => true,
      :return_type => :integer
    },
    :day => { 
      :args => [[:field,:datetime,:date]],
      :resolve_for_type => true,
      :return_type => :integer
    },
    :hour => { 
      :args => [[:field,:datetime,:date]],
      :resolve_for_type => true,
      :return_type => :integer
    },
    :minute => { 
      :args => [[:field,:datetime,:date]],
      :resolve_for_type => true,
      :return_type => :integer
    },
    :second => { 
      :args => [[:field,:datetime,:date]],
      :resolve_for_type => true,
      :return_type => :integer
    },
    :fractionalseconds => { 
      :args => [[:field,:datetime,:date]],
      :resolve_for_type => true,
      :return_type => :decimal
    },
    :range => {
      :args => [:character, :character],
      :return_type => :character
    },
    :wkt => {
      :args => [:character],
      :return_type => :shape
    }
  }
  
  # Construct a resolver instance for a function
  # name: function name (String)
  # args: array of literal hashes of the format {:type=><literal_type>, :value=><escaped_literal_value>}.
  #       Empty arry for functions that have no arguments.
  def initialize(name, args)
    @name = name
    @args = args
    @errors = []
  end
  
  # Validate the function instance prior to calling it. All validation failures will show up in the
  # errors array.
  def validate()
    name = @name.to_sym
    unless support.has_key?(name)
      @errors << Sparkql::ParserError.new(:token => @name, 
        :message => "Unsupported function call '#{@name}' for expression",
        :status => :fatal )
      return
    end

    required_args = support[name][:args]
    total_args = required_args + Array(support[name][:opt_args]).collect {|args| args[:type]}

    if @args.size < required_args.size || @args.size > total_args.size
      @errors << Sparkql::ParserError.new(:token => @name, 
        :message => "Function call '#{@name}' requires #{required_args.size} arguments",
        :status => :fatal )
      return
    end

    count = 0
    @args.each do |arg|
      unless Array(total_args[count]).include?(arg[:type])
        @errors << Sparkql::ParserError.new(:token => @name, 
          :message => "Function call '#{@name}' has an invalid argument at #{arg[:value]}",
          :status => :fatal )
      end
      count +=1
    end

    if name == :cast
      type = @args.last[:value]
      if !VALID_CAST_TYPES.include?(type.to_sym)
        @errors << Sparkql::ParserError.new(:token => @name,
                                            :message => "Function call '#{@name}' requires a castable type.",
                                            :status => :fatal )
        return
      end
    end
  end
  
  def return_type
    name = @name.to_sym

    if name == :cast
      @args.last[:value].to_sym
    else
      support[@name.to_sym][:return_type]
    end
  end
  
  def errors
    @errors
  end
  
  def errors?
    @errors.size > 0
  end
  
  def support
    SUPPORTED_FUNCTIONS
  end
  
  # Execute the function
  def call()
    real_vals = @args.map { |i| i[:value]}
    name = @name.to_sym

    required_args = support[name][:args]
    total_args = required_args + Array(support[name][:opt_args]).collect {|args| args[:default]}
    fill_in_optional_args = total_args.drop(real_vals.length)

    fill_in_optional_args.each do |default|
      real_vals << default
    end
    method = name
    if support[name][:resolve_for_type]
      method_type =  @args.first[:type]
      method = "#{method}_#{method_type}"
    end
    v = self.send(method, *real_vals)

    unless v.nil? || v.key?(:function_name)
      v[:function_name] = @name
      v[:function_parameters] = real_vals
    end

    v
  end
  
  protected 
  
  # Supported function calls

  def regex(regular_expression, flags)

    unless (flags.chars.to_a - VALID_REGEX_FLAGS).empty?
      @errors << Sparkql::ParserError.new(:token => regular_expression,
        :message => "Invalid Regexp",
        :status => :fatal)
      return
    end

    begin
      Regexp.new(regular_expression)
    rescue
      @errors << Sparkql::ParserError.new(:token => regular_expression,
        :message => "Invalid Regexp",
        :status => :fatal)
      return
    end

    {
      :type => :character,
      :value => regular_expression
    }
  end

  def trim_field(arg)
    {
      :type => :function,
      :value => "trim",
      :args => [arg]
    }
  end

  def trim_character(arg)
    {
      :type => :character,
      :value => arg.strip
    }
  end

  def substring_field(field, first_index, number_chars)
    return if substring_index_error?(number_chars)
    {
      :type => :function,
      :value => "substring",
      :args => [field, first_index, number_chars]
    }
  end

  def substring_character(character, first_index, number_chars)
    return if substring_index_error?(number_chars)

    second_index = if number_chars.nil?
      -1
    else
      number_chars + first_index - 1
    end

    new_string = character[first_index..second_index].to_s

    {
      :type => :character,
      :value => new_string
    }
  end

  def substring_index_error?(second_index)
    if second_index.to_i < 0
      @errors << Sparkql::ParserError.new(:token => second_index,
        :message => "Function call 'substring' may not have a negative integer for its second parameter",
        :status => :fatal)
      true
    end
    false
  end

  def tolower_character(string)
    {
      :type => :character,
      :value => "'#{string.to_s.downcase}'"
    }
  end

  def tolower_field(arg)
    {
      :type => :function,
      :value => "tolower",
      :args => [arg]
    }
  end

  def toupper_character(string)
    {
      :type => :character,
      :value => "'#{string.to_s.upcase}'"
    }
  end

  def toupper_field(arg)
    {
      :type => :function,
      :value => "toupper",
      :args => [arg]
    }
  end

  def length_character(string)
    {
      :type => :integer,
      :value => "#{string.size}"
    }
  end

  def length_field(arg)
    {
      :type => :function,
      :value => "length",
      :args => [arg]
    }
  end

  def startswith(string)
    # Wrap this string in quotes, as we effectively translate
    #   City Eq startswith('far')
    # ...to...
    #    City Eq '^far'
    #
    # The string passed in will merely be "far", rather than
    # the string literal "'far'".
    string = Regexp.escape(string)
    new_value = "^#{string}"

    {
      :function_name => "regex",
      :function_parameters => [new_value, ''],
      :type => :character,
      :value => new_value
    }
  end

  def endswith(string)
    # Wrap this string in quotes, as we effectively translate
    #   City Eq endswith('far')
    # ...to...
    #    City Eq regex('far$')
    #
    # The string passed in will merely be "far", rather than
    # the string literal "'far'".
    string = Regexp.escape(string)
    new_value = "#{string}$"

    {
      :function_name => "regex",
      :function_parameters => [new_value, ''],
      :type => :character,
      :value => new_value
    }
  end

  def contains(string)
    # Wrap this string in quotes, as we effectively translate
    #   City Eq contains('far')
    # ...to...
    #    City Eq regex('far')
    #
    # The string passed in will merely be "far", rather than
    # the string literal "'far'".
    string = Regexp.escape(string)
    new_value = "#{string}"

    {
      :function_name => "regex",
      :function_parameters => [new_value, ''],
      :type => :character,
      :value => new_value
    }
  end

  # Offset the current timestamp by a number of days
  def days(num)
    # date calculated as the offset from midnight tommorrow. Zero will provide values for all times 
    # today.
    d = Date.today + num
    {
      :type => :date,
      :value => d.strftime(STRFTIME_DATE_FORMAT)
    }
  end
  
  # The current timestamp
  def now()
    {
      :type => :datetime,
      :value => Time.now.iso8601
    }
  end

  def maxdatetime()
    {
      :type => :datetime,
      :value => MAX_DATE_TIME
    }
  end

  def mindatetime()
    {
      :type => :datetime,
      :value => MIN_DATE_TIME
    }
  end

  def floor_decimal(arg)
    {
      :type => :integer,
      :value => arg.floor.to_s
    }
  end

  def floor_field(arg)
    {
      :type => :function,
      :value => "floor",
      :args => [arg]
    }
  end

  def ceiling_decimal(arg)
    {
      :type => :integer,
      :value => arg.ceil.to_s
    }
  end

  def ceiling_field(arg)
    {
      :type => :function,
      :value => "ceiling",
      :args => [arg]
    }
  end

  def round_decimal(arg)
    {
      :type => :integer,
      :value => arg.round.to_s
    }
  end

  def round_field(arg)
    {
      :type => :function,
      :value => "round",
      :args => [arg]
    }
  end

  def indexof(arg1, arg2)
    {
      :type => :function,
      :value => "indexof",
      :args => [arg1, arg2]
    }
  end

  def concat_character(arg1, arg2)
    {
      :type => :character,
      :value => "'#{arg1}#{arg2}'"
    }
  end

  def concat_field(arg1, arg2)
    {
      :type => :function,
      :value => 'concat',
      :args => [arg1, arg2]
    }
  end

  def date_field(arg)
    {
      :type => :function,
      :value => "date",
      :args => [arg]
    }
  end
  
  def time_field(arg)
    {
      :type => :function,
      :value => "time",
      :args => [arg]
    }
  end

  def year_field(arg)
    {
      :type => :function,
      :value => "year",
      :args => [arg]
    }
  end

  def month_field(arg)
    {
      :type => :function,
      :value => "month",
      :args => [arg]
    }
  end

  def day_field(arg)
    {
      :type => :function,
      :value => "day",
      :args => [arg]
    }
  end

  def hour_field(arg)
    {
      :type => :function,
      :value => "hour",
      :args => [arg]
    }
  end

  def minute_field(arg)
    {
      :type => :function,
      :value => "minute",
      :args => [arg]
    }
  end

  def second_field(arg)
    {
      :type => :function,
      :value => "second",
      :args => [arg]
    }
  end

  def fractionalseconds_field(arg)
    {
      :type => :function,
      :value => "fractionalseconds",
      :args => [arg]
    }
  end

  def date_datetime(dt)
    {
      :type => :date,
      :value => dt.strftime(STRFTIME_DATE_FORMAT)
    }
  end
  
  def time_datetime(dt)
    {
      :type => :time,
      :value => dt.strftime(STRFTIME_TIME_FORMAT)
    }
  end

  def months num_months
    d = DateTime.now >> num_months
    {
      :type => :date,
      :value => d.strftime(STRFTIME_DATE_FORMAT)
    }
  end

  def years num_years
    d = DateTime.now >> (num_years * 12)
    {
      :type => :date,
      :value => d.strftime(STRFTIME_DATE_FORMAT)
    }
  end
  
  # TODO Donuts: to extend, we'd just replace (coords) param with (linear_ring1,linear_ring2, ...)
  def polygon(coords)
    new_coords = parse_coordinates(coords)
    unless new_coords.size > 2
      @errors << Sparkql::ParserError.new(:token => coords, 
        :message => "Function call 'polygon' requires at least three coordinates",
        :status => :fatal )
      return
    end

    # auto close the polygon if it's open
    unless new_coords.first == new_coords.last
      new_coords << new_coords.first.clone
    end
    
    shape = GeoRuby::SimpleFeatures::Polygon.from_coordinates([new_coords])
    {
      :type => :shape,
      :value => shape
    }
  end

  def linestring(coords)
    new_coords = parse_coordinates(coords)
    unless new_coords.size > 1
      @errors << Sparkql::ParserError.new(:token => coords,
        :message => "Function call 'linestring' requires at least two coordinates",
        :status => :fatal )
      return
    end

    shape = GeoRuby::SimpleFeatures::LineString.from_coordinates(new_coords)
    {
      :type => :shape,
      :value => shape
    }
  end

  def wkt(wkt_string)
    shape = GeoRuby::SimpleFeatures::Geometry.from_ewkt(wkt_string)
    {
      :type => :shape,
      :value => shape
    }
  rescue GeoRuby::SimpleFeatures::EWKTFormatError
    @errors << Sparkql::ParserError.new(:token => wkt_string,
      :message => "Function call 'wkt' requires a valid wkt string",
      :status => :fatal )
    return
  end
    
  def rectangle(coords)
    bounding_box = parse_coordinates(coords)
    unless bounding_box.size == 2
      @errors << Sparkql::ParserError.new(:token => coords, 
        :message => "Function call 'rectangle' requires two coordinates for the bounding box",
        :status => :fatal )
      return
    end
    poly_coords = [
                    bounding_box.first, 
                    [bounding_box.last.first, bounding_box.first.last],
                    bounding_box.last,
                    [bounding_box.first.first, bounding_box.last.last],
                    bounding_box.first.clone, 
                  ]
    shape = GeoRuby::SimpleFeatures::Polygon.from_coordinates([poly_coords])
    {
      :type => :shape,
      :value => shape
    }
  end
  
  def radius(coords, length)

    unless length > 0
      @errors << Sparkql::ParserError.new(:token => length, 
        :message => "Function call 'radius' length must be positive",
        :status => :fatal )
      return
    end

    # The radius() function is overloaded to allow an identifier
    # to be specified over lat/lon.  This identifier should specify a
    # record that, in turn, references a lat/lon. Naturally, this won't be
    # validated here.
    shape_error = false
    shape = if is_coords?(coords)
              new_coords = parse_coordinates(coords)
              if new_coords.size != 1
                shape_error = true
              else
                GeoRuby::SimpleFeatures::Circle.from_coordinates(new_coords.first, length);
              end
            elsif Sparkql::Geo::RecordRadius.valid_record_id?(coords)
              Sparkql::Geo::RecordRadius.new(coords, length)
            else
              shape_error = true
            end

    if shape_error
      @errors << Sparkql::ParserError.new(:token => coords, 
        :message => "Function call 'radius' requires one coordinate for the center",
        :status => :fatal )
      return
    end

    {
      :type => :shape,
      :value => shape 
    }
  end
  
  def range(start_str, end_str)
    {
      :type => :character,
      :value => [start_str.to_s, end_str.to_s]
    }
  end

  def cast_field(value, type)
    {
      :type => :function,
      :value => "cast",
      :args => [value, type]
    }
  end

  def cast(value, type)
    if value == 'NULL'
      value = nil
    end

    new_type = type.to_sym
    {
      type: new_type,
      value: cast_literal(value, new_type)
    }
  rescue
    {
      type: :null,
      value: 'NULL'
    }
  end

  def valid_cast_type?(type)
    if VALID_CAST_TYPES.key?(type.to_sym)
      true
    else
      @errors << Sparkql::ParserError.new(:token => coords,
                                          :message => "Function call 'cast' requires a castable type.",
                                          :status => :fatal )
      false
    end
  end

  def cast_null(value, type)
    cast(value, type)
  end

  def cast_decimal(value, type)
    cast(value, type)
  end

  def cast_character(value, type)
    cast(value, type)
  end

  def cast_literal(value, type)
    case type
    when :character
      "'#{value.to_s}'"
    when :integer
      if value.nil?
        '0'
      else
        Integer(Float(value)).to_s
      end
    when :decimal
      if value.nil?
        '0.0'
      else
        Float(value).to_s
      end
    when :null
      'NULL'
    end
  end

  private

  def is_coords?(coord_string)
    coord_string.split(" ").size > 1
  end

  def parse_coordinates coord_string
    terms = coord_string.strip.split(',')
    coords = terms.map do |term|
      term.strip.split(/\s+/).reverse.map { |i| i.to_f }
    end
    coords
  rescue
    @errors << Sparkql::ParserError.new(:token => coord_string, 
      :message => "Unable to parse coordinate string.",
      :status => :fatal )
  end
  
end
