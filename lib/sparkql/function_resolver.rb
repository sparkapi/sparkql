require 'time'

# Binding class to all supported function calls in the parser. Current support requires that the 
# resolution of function calls to happen on the fly at parsing time at which point a value and 
# value type is required, just as literals would be returned to the expression tokenization level.
#
# Name and argument requirements for the function should match the function declaration in 
# SUPPORTED_FUNCTIONS which will run validation on the function syntax prior to execution.
class Sparkql::FunctionResolver
  SECONDS_IN_DAY = 60 * 60 * 24
  
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
    :days => {
      :args => [:integer],
      :return_type => :datetime
    }, 
    :now => { 
      :args => [],
      :return_type => :datetime
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
    unless required_args.size == @args.size
      @errors << Sparkql::ParserError.new(:token => @name, 
        :message => "Function call '#{@name}' requires #{required_args.size} arguments",
        :status => :fatal )
      return
    end
    
    count = 0
    @args.each do |arg|
      unless arg[:type] == required_args[count]
        @errors << Sparkql::ParserError.new(:token => @name, 
          :message => "Function call '#{@name}' has an invalid argument at #{arg[:value]}",
          :status => :fatal )
      end
      count +=1
    end
  end
  
  def return_type
    supported[@name.to_sym][:return_type]
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
    self.send(@name.to_sym, *real_vals)
  end
  
  protected 
  
  # Supported function calls
  
  # Offset the current timestamp by a number of days
  def days(num)
    # date calculated as the offset from midnight tommorrow. Zero will provide values for all times 
    # today.
    d = Date.today + num
    {
      :type => :date,
      :value => d.to_s
    }
  end
  
  # The current timestamp
  def now()
    {
      :type => :datetime,
      :value => Time.now.iso8601
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

    shape = GeoRuby::SimpleFeatures::Polygon.from_coordinates([new_coords])
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
                  ]
    shape = GeoRuby::SimpleFeatures::Polygon.from_coordinates([poly_coords])
    {
      :type => :shape,
      :value => shape
    }
  end
  
  def radius(coords, length)
   new_coords = parse_coordinates(coords)
    unless new_coords.size == 1
      @errors << Sparkql::ParserError.new(:token => coords, 
        :message => "Function call 'radius' requires one coordinate for the center",
        :status => :fatal )
      return
    end
    unless length > 0
      @errors << Sparkql::ParserError.new(:token => length, 
        :message => "Function call 'radius' length must be positive",
        :status => :fatal )
      return
    end
    
    shape = GeoRuby::SimpleFeatures::Circle.from_coordinates(new_coords.first, length);
    {
      :type => :shape,
      :value => shape 
    }
  end
  
  private
  
  def parse_coordinates coord_string
    terms = coord_string.strip.split(',')
    coords = terms.map do |term|
      term.strip.split(/\s+/).map { |i| i.to_f }
    end
    coords
  rescue => e
    @errors << Sparkql::ParserError.new(:token => coord_string, 
      :message => "Unable to parse coordinate string.",
      :status => :fatal )
  end
  
end