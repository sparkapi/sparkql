module Sparkql
  module Nodes
    class Function < Node
      attr_accessor :name, :args
      def initialize(name, args)
        @name = name
        @args = args
      end
    end
  end
end
