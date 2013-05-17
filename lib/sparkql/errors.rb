module Sparkql

class ErrorsProcessor
  attr_accessor :errors

  def initialize( errors )
    @errors = errors || []
  end

  # true if the error stack contains at least one error
  def errors?
    @errors.size > 0
  end

  # true if there is at least one error of status :status in the error stack
  def errors_by_status?( status )
    @errors.each do | error |
      return true if status == error.status
    end
    false
  end

  # true if there is at least one :fatal error in the error stack
  def fatal_errors?
    errors_by_status? :fatal
  end

  # true if there is at least one :dropped error in the error stack
  def dropped_errors?
    errors_by_status? :dropped
  end

  # true if there is at least one :recovered error in the error stack
  def recovered_errors?
    errors_by_status? :recovered
  end

end

class ParserError
  attr_accessor :token, :expression, :message, :status, :recovered_as
  attr_writer :syntax, :constraint

  def initialize(error_hash={})
    @token = error_hash[:token]
    @expression = error_hash[:expression]
    @message = error_hash[:message]
    @status = error_hash[:status]
    @recovered_as = error_hash[:recovered_as]
    @recovered_as = error_hash[:recovered_as]
    self.syntax= error_hash[:syntax] == false ? false : true
    self.constraint= error_hash[:constraint] == false ? false : true
  end
  
  def syntax?
    @syntax
  end
  
  def constraint?
    @constraint
  end

  def to_s
    str = case @status
          # Do nothing. Dropping the expressions isn't special
          when :dropped then "Dropped: " 
          # Fatal errors cannot be recovered from, and should cause anaylisis or
          # compilation to stop.
          when :fatal then "Fatal: "
          # Recovered errors are those that are syntatically
          # or symantically incorrect, but are ones that we could "guess" at the
          # intention
          when :recovered then
            "Recovered as #{@recovered_as}: "
          else ""
          end
    str += "<#{@token}> in " unless @token.nil?
    str += "<#{@expression}>: #{@message}."
    str
  end
end

end