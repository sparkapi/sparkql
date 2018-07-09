module Sparkql
  module Nodes
    class Operator < Node
      attr_accessor :left, :right
      def initialize left, right
        @left = left
        @right = right
      end

      def self.supported_types
        raise "Implement this method BRO!"
      end
    end
  end
end
