module Sparkql
  module Nodes
    class And < Node
      attr_accessor :left, :right
      def initialize left, right
        @left = left
        @right = right
      end
    end
  end
end

