module Sparkql
  module Nodes
    class Function < Node
      attr_accessor :name, :args
      def initialize(name, args)
        @name = name
        @args = args
        @resolver = FunctionResolver.new(name, @args)
      end

      def errors
        # TODO: bring over FunctionResolver, fix methods which throw errors on call()
        # and instead, validate on #validate
        # Functions should be evaluated during evaluation, not in the parser
        @resolver.validate
        @resolver.call

        @resolver.errors
      end

      def value
        @resolver.call
      end
    end
  end
end
