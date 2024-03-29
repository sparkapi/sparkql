# frozen_string_literal: true

require 'time'
require 'geo_ruby'
require 'geo_ruby/ewk'
require 'sparkql/geo'

module Sparkql
  # Binding class to all supported function calls in the parser. Current support requires that the
  # resolution of function calls to happen on the fly at parsing time at which point a value and
  # value type is required, just as literals would be returned to the expression tokenization level.
  #
  # Name and argument requirements for the function should match the function declaration in
  # SUPPORTED_FUNCTIONS which will run validation on the function syntax prior to execution.
  class FunctionResolver
    SECONDS_IN_MINUTE = 60
    SECONDS_IN_HOUR = SECONDS_IN_MINUTE * 60
    SECONDS_IN_DAY = SECONDS_IN_HOUR * 24
    STRFTIME_DATE_FORMAT = '%Y-%m-%d'
    STRFTIME_TIME_FORMAT = '%H:%M:%S.%N'
    VALID_REGEX_FLAGS = ['', 'i'].freeze
    MIN_DATE_TIME = Time.new(1970, 1, 1, 0, 0, 0, '+00:00').iso8601
    MAX_DATE_TIME = Time.new(9999, 12, 31, 23, 59, 59, '+00:00').iso8601
    VALID_CAST_TYPES = %i[field character decimal integer].freeze

    SUPPORTED_FUNCTIONS = {
      all: {
        args: [:field],
        return_type: :all
      },
      polygon: {
        args: [:character],
        return_type: :shape
      },
      rectangle: {
        args: [:character],
        return_type: :shape
      },
      radius: {
        args: [:character, %i[decimal integer]],
        return_type: :shape
      },
      regex: {
        args: [:character],
        opt_args: [{
          type: :character,
          default: ''
        }],
        return_type: :character
      },
      substring: {
        args: [%i[field character], :integer],
        opt_args: [{
          type: :integer
        }],
        resolve_for_type: true,
        return_type: :character
      },
      trim: {
        args: [%i[field character]],
        resolve_for_type: true,
        return_type: :character
      },
      tolower: {
        args: [%i[field character]],
        resolve_for_type: true,
        return_type: :character
      },
      toupper: {
        args: [%i[field character]],
        resolve_for_type: true,
        return_type: :character
      },
      length: {
        args: [%i[field character]],
        resolve_for_type: true,
        return_type: :integer
      },
      indexof: {
        args: [%i[field character], :character],
        return_type: :integer
      },
      concat: {
        args: [%i[field character], :character],
        resolve_for_type: true,
        return_type: :character
      },
      cast: {
        args: [%i[field character decimal integer null], :character],
        resolve_for_type: true
      },
      round: {
        args: [%i[field decimal]],
        resolve_for_type: true,
        return_type: :integer
      },
      ceiling: {
        args: [%i[field decimal]],
        resolve_for_type: true,
        return_type: :integer
      },
      floor: {
        args: [%i[field decimal]],
        resolve_for_type: true,
        return_type: :integer
      },
      startswith: {
        args: [:character],
        return_type: :startswith
      },
      endswith: {
        args: [:character],
        return_type: :endswith
      },
      contains: {
        args: [:character],
        return_type: :contains
      },
      linestring: {
        args: [:character],
        return_type: :shape
      },
      seconds: {
        args: [:integer],
        return_type: :datetime
      },
      minutes: {
        args: [:integer],
        return_type: :datetime
      },
      hours: {
        args: [:integer],
        return_type: :datetime
      },
      days: {
        args: [:integer],
        return_type: :datetime
      },
      weekdays: {
        args: [:integer],
        return_type: :datetime
      },
      months: {
        args: [:integer],
        return_type: :datetime
      },
      years: {
        args: [:integer],
        return_type: :datetime
      },
      now: {
        args: [],
        return_type: :datetime
      },
      maxdatetime: {
        args: [],
        return_type: :datetime
      },
      mindatetime: {
        args: [],
        return_type: :datetime
      },
      date: {
        args: [%i[field datetime date]],
        resolve_for_type: true,
        return_type: :date
      },
      time: {
        args: [%i[field datetime date]],
        resolve_for_type: true,
        return_type: :time
      },
      year: {
        args: [%i[field datetime date]],
        resolve_for_type: true,
        return_type: :integer
      },
      dayofyear: {
        args: [%i[field datetime date]],
        resolve_for_type: true,
        return_type: :integer
      },
      month: {
        args: [%i[field datetime date]],
        resolve_for_type: true,
        return_type: :integer
      },
      day: {
        args: [%i[field datetime date]],
        resolve_for_type: true,
        return_type: :integer
      },
      dayofweek: {
        args: [%i[field datetime date]],
        resolve_for_type: true,
        return_type: :integer
      },
      hour: {
        args: [%i[field datetime date]],
        resolve_for_type: true,
        return_type: :integer
      },
      minute: {
        args: [%i[field datetime date]],
        resolve_for_type: true,
        return_type: :integer
      },
      second: {
        args: [%i[field datetime date]],
        resolve_for_type: true,
        return_type: :integer
      },
      fractionalseconds: {
        args: [%i[field datetime date]],
        resolve_for_type: true,
        return_type: :decimal
      },
      range: {
        args: %i[character character],
        return_type: :character
      },
      wkt: {
        args: [:character],
        return_type: :shape
      }
    }.freeze

    def self.lookup(function_name)
      SUPPORTED_FUNCTIONS[function_name.to_sym]
    end

    # Construct a resolver instance for a function
    # name: function name (String)
    # args: array of literal hashes of the format {:type=><literal_type>, :value=><escaped_literal_value>}.
    #       Empty arry for functions that have no arguments.
    def initialize(name, args, options = {})
      @name = name
      @args = args
      @errors = []
      @current_timestamp = options[:current_timestamp]
    end

    # Validate the function instance prior to calling it. All validation failures will show up in the
    # errors array.
    def validate
      name = @name.to_sym
      unless support.key?(name)
        @errors << Sparkql::ParserError.new(token: @name,
                                            message: "Unsupported function call '#{@name}' for expression",
                                            status: :fatal)
        return
      end

      required_args = support[name][:args]
      total_args = required_args + Array(support[name][:opt_args]).collect { |args| args[:type] }

      if @args.size < required_args.size || @args.size > total_args.size
        @errors << Sparkql::ParserError.new(token: @name,
                                            message: "Function call '#{@name}' requires #{required_args.size} arguments",
                                            status: :fatal)
        return
      end

      count = 0
      @args.each do |arg|
        type = arg[:type] == :function ? arg[:return_type] : arg[:type]
        unless Array(total_args[count]).include?(type)
          @errors << Sparkql::ParserError.new(token: @name,
                                              message: "Function call '#{@name}' has an invalid argument at #{arg[:value]}",
                                              status: :fatal)
        end
        count += 1
      end

      if name == :cast
        type = @args.last[:value]
        unless VALID_CAST_TYPES.include?(type.to_sym)
          @errors << Sparkql::ParserError.new(token: @name,
                                              message: "Function call '#{@name}' requires a castable type.",
                                              status: :fatal)
          return
        end
      end

      substring_index_error?(@args[2][:value]) if name == :substring && !@args[2].nil?
    end

    def return_type
      name = @name.to_sym

      if name == :cast
        @args.last[:value].to_sym
      else
        support[@name.to_sym][:return_type]
      end
    end

    attr_reader :errors

    def errors?
      @errors.size.positive?
    end

    def support
      SUPPORTED_FUNCTIONS
    end

    # Execute the function
    def call
      real_vals = @args.map { |i| i[:value] }
      name = @name.to_sym

      field = @args.find do |i|
        i[:type] == :field || i.key?(:field)
      end

      field = field[:type] == :function ? field[:field] : field[:value] unless field.nil?

      required_args = support[name][:args]
      total_args = required_args + Array(support[name][:opt_args]).collect { |args| args[:default] }

      fill_in_optional_args = total_args.drop(real_vals.length)

      fill_in_optional_args.each do |default|
        real_vals << default
      end

      v = if field.nil?
            method = name
            if support[name][:resolve_for_type]
              method_type = @args.first[:type]
              method = "#{method}_#{method_type}"
            end
            send(method, *real_vals)
          else
            {
              type: :function,
              return_type: return_type,
              value: name.to_s
            }
          end

      return if v.nil?

      unless v.key?(:function_name)
        v.merge!(function_parameters: real_vals,
                 function_name: @name)
      end

      v.merge!(args: @args,
               field: field)

      v
    end

    protected

    # Supported function calls

    def regex(regular_expression, flags)
      unless (flags.chars.to_a - VALID_REGEX_FLAGS).empty?
        @errors << Sparkql::ParserError.new(token: regular_expression,
                                            message: 'Invalid Regexp',
                                            status: :fatal)
        return
      end

      begin
        Regexp.new(regular_expression)
      rescue StandardError
        @errors << Sparkql::ParserError.new(token: regular_expression,
                                            message: 'Invalid Regexp',
                                            status: :fatal)
        return
      end

      {
        type: :character,
        value: regular_expression
      }
    end

    def trim_character(arg)
      {
        type: :character,
        value: arg.strip
      }
    end

    def substring_character(character, first_index, number_chars)
      second_index = if number_chars.nil?
                       -1
                     else
                       number_chars + first_index - 1
                     end

      new_string = character[first_index..second_index].to_s

      {
        type: :character,
        value: new_string
      }
    end

    def substring_index_error?(second_index)
      if second_index.to_i.negative?
        @errors << Sparkql::ParserError.new(token: second_index,
                                            message: "Function call 'substring' may not have a negative integer for its second parameter",
                                            status: :fatal)
        true
      end
      false
    end

    def tolower(_args)
      {
        type: :character,
        value: 'tolower'
      }
    end

    def tolower_character(string)
      {
        type: :character,
        value: "'#{string.to_s.downcase}'"
      }
    end

    def toupper_character(string)
      {
        type: :character,
        value: "'#{string.to_s.upcase}'"
      }
    end

    def length_character(string)
      {
        type: :integer,
        value: string.size.to_s
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
        function_name: 'regex',
        function_parameters: [new_value, ''],
        type: :character,
        value: new_value
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
        function_name: 'regex',
        function_parameters: [new_value, ''],
        type: :character,
        value: new_value
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
      new_value = string.to_s

      {
        function_name: 'regex',
        function_parameters: [new_value, ''],
        type: :character,
        value: new_value
      }
    end

    # Offset the current timestamp by a number of seconds
    def seconds(num)
      t = current_time + num
      {
        type: :datetime,
        value: t.iso8601
      }
    end

    # Offset the current timestamp by a number of minutes
    def minutes(num)
      t = current_time + num * SECONDS_IN_MINUTE
      {
        type: :datetime,
        value: t.iso8601
      }
    end

    # Offset the current timestamp by a number of hours
    def hours(num)
      t = current_time + num * SECONDS_IN_HOUR
      {
        type: :datetime,
        value: t.iso8601
      }
    end

    # Offset the current timestamp by a number of days
    def days(number_of_days)
      # date calculated as the offset from midnight tommorrow. Zero will provide values for all times
      # today.
      d = current_date + number_of_days
      {
        type: :date,
        value: d.strftime(STRFTIME_DATE_FORMAT)
      }
    end

    def weekdays(number_of_days)
      today = current_date
      weekend_start = today.saturday? || today.sunday?
      direction = number_of_days.positive? ? 1 : -1
      weeks = (number_of_days / 5.0).to_i
      remaining = number_of_days.abs % 5

      # Jump ahead the number of weeks represented in the input
      today += weeks * 7

      # Now iterate on the remaining weekdays
      remaining.times do |_i|
        today += direction
        today += direction while today.saturday? || today.sunday?
      end

      # If we end on the weekend, bump accordingly
      while today.saturday? || today.sunday?
        # If we start and end on the weekend, wind things back to the next
        # appropriate weekday.
        if weekend_start && remaining.zero?
          today -= direction
        else
          today += direction
        end
      end

      {
        type: :date,
        value: today.strftime(STRFTIME_DATE_FORMAT)
      }
    end

    # The current timestamp
    def now
      {
        type: :datetime,
        value: current_time.iso8601
      }
    end

    def maxdatetime
      {
        type: :datetime,
        value: MAX_DATE_TIME
      }
    end

    def mindatetime
      {
        type: :datetime,
        value: MIN_DATE_TIME
      }
    end

    def floor_decimal(arg)
      {
        type: :integer,
        value: arg.floor.to_s
      }
    end

    def ceiling_decimal(arg)
      {
        type: :integer,
        value: arg.ceil.to_s
      }
    end

    def round_decimal(arg)
      {
        type: :integer,
        value: arg.round.to_s
      }
    end

    def indexof(arg1, arg2)
      {
        value: 'indexof',
        args: [arg1, arg2]
      }
    end

    def concat_character(arg1, arg2)
      {
        type: :character,
        value: "'#{arg1}#{arg2}'"
      }
    end

    def date_datetime(datetime)
      {
        type: :date,
        value: datetime.strftime(STRFTIME_DATE_FORMAT)
      }
    end

    def time_datetime(datetime)
      {
        type: :time,
        value: datetime.strftime(STRFTIME_TIME_FORMAT)
      }
    end

    def months(num_months)
      # DateTime usage. There's a better means to do this with Time via rails
      d = (current_timestamp.to_datetime >> num_months).to_time
      {
        type: :date,
        value: d.strftime(STRFTIME_DATE_FORMAT)
      }
    end

    def years(num_years)
      # DateTime usage. There's a better means to do this with Time via rails
      d = (current_timestamp.to_datetime >> (num_years * 12)).to_time
      {
        type: :date,
        value: d.strftime(STRFTIME_DATE_FORMAT)
      }
    end

    def polygon(coords)
      new_coords = parse_coordinates(coords)
      unless new_coords.size > 2
        @errors << Sparkql::ParserError.new(token: coords,
                                            message: "Function call 'polygon' requires at least three coordinates",
                                            status: :fatal)
        return
      end

      # auto close the polygon if it's open
      new_coords << new_coords.first.clone unless new_coords.first == new_coords.last

      shape = GeoRuby::SimpleFeatures::Polygon.from_coordinates([new_coords])
      {
        type: :shape,
        value: shape
      }
    end

    def linestring(coords)
      new_coords = parse_coordinates(coords)
      unless new_coords.size > 1
        @errors << Sparkql::ParserError.new(token: coords,
                                            message: "Function call 'linestring' requires at least two coordinates",
                                            status: :fatal)
        return
      end

      shape = GeoRuby::SimpleFeatures::LineString.from_coordinates(new_coords)
      {
        type: :shape,
        value: shape
      }
    end

    def wkt(wkt_string)
      shape = GeoRuby::SimpleFeatures::Geometry.from_ewkt(wkt_string)
      {
        type: :shape,
        value: shape
      }
    rescue GeoRuby::SimpleFeatures::EWKTFormatError
      @errors << Sparkql::ParserError.new(token: wkt_string,
                                          message: "Function call 'wkt' requires a valid wkt string",
                                          status: :fatal)
      nil
    end

    def rectangle(coords)
      bounding_box = parse_coordinates(coords)
      unless bounding_box.size == 2
        @errors << Sparkql::ParserError.new(token: coords,
                                            message: "Function call 'rectangle' requires two coordinates for the bounding box",
                                            status: :fatal)
        return
      end
      poly_coords = [
        bounding_box.first,
        [bounding_box.last.first, bounding_box.first.last],
        bounding_box.last,
        [bounding_box.first.first, bounding_box.last.last],
        bounding_box.first.clone
      ]
      shape = GeoRuby::SimpleFeatures::Polygon.from_coordinates([poly_coords])
      {
        type: :shape,
        value: shape
      }
    end

    def radius(coords, length)
      unless length.positive?
        @errors << Sparkql::ParserError.new(token: length,
                                            message: "Function call 'radius' length must be positive",
                                            status: :fatal)
        return
      end

      # The radius() function is overloaded to allow an identifier
      # to be specified over lat/lon.  This identifier should specify a
      # record that, in turn, references a lat/lon. Naturally, this won't be
      # validated here.
      shape_error = false
      shape = if coords?(coords)
                new_coords = parse_coordinates(coords)
                if new_coords.size != 1
                  shape_error = true
                else
                  GeoRuby::SimpleFeatures::Circle.from_coordinates(new_coords.first, length)
                end
              elsif Sparkql::Geo::RecordRadius.valid_record_id?(coords)
                Sparkql::Geo::RecordRadius.new(coords, length)
              else
                shape_error = true
              end

      if shape_error
        @errors << Sparkql::ParserError.new(token: coords,
                                            message: "Function call 'radius' requires one coordinate for the center",
                                            status: :fatal)
        return
      end

      {
        type: :shape,
        value: shape
      }
    end

    def range(start_str, end_str)
      {
        type: :character,
        value: [start_str.to_s, end_str.to_s]
      }
    end

    def cast(value, type)
      value = nil if value == 'NULL'

      new_type = type.to_sym
      {
        type: new_type,
        value: cast_literal(value, new_type)
      }
    rescue StandardError
      {
        type: :null,
        value: 'NULL'
      }
    end

    def valid_cast_type?(type)
      if VALID_CAST_TYPES.key?(type.to_sym)
        true
      else
        @errors << Sparkql::ParserError.new(token: coords,
                                            message: "Function call 'cast' requires a castable type.",
                                            status: :fatal)
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
        "'#{value}'"
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

    def current_date
      current_timestamp.to_date
    end

    def current_time
      current_timestamp
    end

    def current_timestamp
      @current_timestamp ||= Time.now
    end

    private

    def coords?(coord_string)
      coord_string.split(' ').size > 1
    end

    def parse_coordinates(coord_string)
      terms = coord_string.strip.split(',')
      terms.map do |term|
        term.strip.split(/\s+/).reverse.map(&:to_f)
      end
    rescue StandardError
      @errors << Sparkql::ParserError.new(token: coord_string,
                                          message: 'Unable to parse coordinate string.',
                                          status: :fatal)
    end
  end
end
