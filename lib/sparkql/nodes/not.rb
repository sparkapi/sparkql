module Sparkql
  module Nodes
    class Not < Node
      attr_accessor :value
      def initialize value
        @value = value
      end
    end
  end
end
