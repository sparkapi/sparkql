module Sparkql
  module Nodes
    class Group < Node
      attr_accessor :value
      def initialize value
        @value = value
      end
    end
  end
end
