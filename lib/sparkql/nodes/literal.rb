module Sparkql
  module Nodes
    class Literal < Node
      attr_accessor :type, :value
      def initialize(one,two)
        @type = one
        @value = two
      end
    end
  end
end
