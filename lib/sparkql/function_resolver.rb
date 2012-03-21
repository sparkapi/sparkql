require 'time'
class Sparkql::FunctionResolver
  SECONDS_IN_DAY = 60 * 60 * 24
  
  SUPPORTED_FUNCTIONS = {
    :days => {
      :args => [:integer],
      :return_type => :datetime
    }, 
    :now => { 
      :args => [],
      :return_type => :datetime
    }
  }
  def initialize(name, args)
    @name = name
    @args = args
    @errors = []
  end
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
  
  def call()
    real_vals = @args.map { |i| i[:value]}
    self.send(@name.to_sym, *real_vals)
  end
  
  def days(num)
    time = Time.now + (num * SECONDS_IN_DAY) 
    {
      :type => :datetime,
      :value => time.iso8601
    }
  end
  
  def now()
    {
      :type => :datetime,
      :value => Time.now.iso8601
    }
  end
end