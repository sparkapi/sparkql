module Sparkql
  module Nodes
    class Function < Node
      attr_reader :args, :errors
      def initialize(args)
        @args = args
      end

      def errors
        errors = []

        min_args = arg_meta.select {|arg| !arg.key?(:default) }.size
        max_args = arg_meta.size

        if @args.size < min_args || @args.size > max_args
          message = if min_args == max_args
                      "requires #{min_args} arguments"
                    else
                      "requires between #{min_args} and #{max_args} arguments"
                    end
          errors << {
            token: 'name',
            message: message,
            status: :fatal,
          }
        end

        arg_meta.each_with_index do |meta, index|
          current_argument = @args[index]

          if !meta[:allow_field] && current_argument.is_a?(Sparkql::Nodes::Identifier)
            errors << {
              token: current_argument,
              message: "Argument does not support a field",
              status: :fatal,
              sytanx: false,
              constraint: true
            }
          end

          if current_argument.is_a?(Sparkql::Nodes::Literal) && !meta[:types].include?(current_argument.type)
            errors << {
              token: current_argument,
              message: "Incorrect argument type: #{current_argument.type}",
              status: :fatal,
              sytanx: false,
              constraint: true
            }
          end

        end

        errors
      end
    end
  end
end
