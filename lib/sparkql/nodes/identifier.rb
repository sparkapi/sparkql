module Sparkql
  module Nodes
    class Identifier < Node
      attr_accessor :value
      def initialize(value)
        @value = value
      end

      # TODO: Remove this. Used for backward compatibility
      def type
        :field
      end
    end
  end
end
