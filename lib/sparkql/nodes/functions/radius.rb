module Sparkql
  module Nodes
    module Functions
      # arg1: TODO
      # arg2: TODO
      class Radius < Function
        ARG_META = [
          {
            types: [:character],
            allow_field: false,
          },
          {
            types: [:decimal, :integer],
            allow_field: false,
          }
        ].freeze

        def arg_meta
          ARG_META
        end

        def errors
          errors = super

          arg2 = @args[1]
          if arg2.is_a?(Sparkql::Nodes::Literal) &&
              [:decimal, :integer].include?(arg2.type) &&
              arg2.value < 0
            errors << {
              token: arg2,
              message: "Second argument cannot be negative",
              status: :fatal,
              sytanx: false,
              constraint: true
            }
          end

          arg1 = @args.first
          if arg1.is_a?(Sparkql::Nodes::Literal) &&
              [:character].include?(arg1.type) &&
              !is_coords?(arg1.value) &&
              !arg1.value.is_a?(String) && arg1.value =~ /^\d{26}$/
            errors << {
              token: arg1,
              message: "First argument must be valid coordinates or a tech id",
              status: :fatal,
              sytanx: false,
              constraint: true
            }
          end

          errors
        end

        private

        def is_coords?(coord_string)
          coord_string.split(" ").size > 1
        end

      end
    end
  end
end
