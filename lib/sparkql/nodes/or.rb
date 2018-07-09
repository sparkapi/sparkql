module Sparkql
  module Nodes
    class Or < Node
      attr_accessor :left, :right
      def initialize left, right
        @left = left
        @right = right
      end
    end
  end
end
