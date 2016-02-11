require 'time'
require 'geo_ruby'
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
      :args => [:character, :decimal],
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
    :date => { 
      :args => [[:field,:datetime]],
      :resolve_for_type => true,
      :return_type => :date
    },
    :time => { 
      :args => [[:field,:datetime]],
      :resolve_for_type => true,
      :return_type => :time
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
  end
  
  def return_type
    support[@name.to_sym][:return_type]
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

    unless v.nil?
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
    rescue => e
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
  rescue => e
    @errors << Sparkql::ParserError.new(:token => coord_string, 
      :message => "Unable to parse coordinate string.",
      :status => :fatal )
  end
  
end
