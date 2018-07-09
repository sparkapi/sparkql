module Sparkql
  module Nodes
    class Literal < Node
      attr_reader :type, :value

      def initialize(type, value)
        @type = type
        @value = Literal.escape_value(type, value)
      end

      def self.escape_value(type, value)
        case type
        when :character
          return character_escape(value)
        when :integer
          return integer_escape(value)
        when :decimal
          return decimal_escape(value)
        when :date
          return date_escape(value)
        when :datetime
          return datetime_escape(value)
        when :time
          return time_escape(value)
        when :boolean
          return boolean_escape(value)
        when :null
          return nil
        end
        value
      end

      def self.character_escape( string )
        string.gsub(/^\'/,'').gsub(/\'$/,'').gsub(/\\'/, "'")
      end

      def self.integer_escape( string )
        string.to_i
      end

      def self.decimal_escape( string )
        string.to_f
      end

      def self.date_escape(string)
        Date.parse(string)
      end

      def self.datetime_escape(string)
        DateTime.parse(string)
      end

      def self.time_escape(string)
        DateTime.parse(string)
      end

      def self.boolean_escape(string)
        "true" == string
      end
    end

  end
end
