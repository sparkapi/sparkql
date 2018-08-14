module Sparkql
  module Nodes
    module Functions
      # arg1: TODO
      # arg2: TODO
      class Regex < Function
        VALID_REGEX_FLAGS = ["", "i"]
        ARG_META = [
          {
            types: [:character],
            allow_field: false,
          },
          {
            types: [:character],
            allow_field: false,
            default: ''
          }
        ].freeze

        def arg_meta
          ARG_META
        end

        def return_type
          :character
        end

        def errors
          errors = super

          if @args[1] && @args[1].type == :character &&
              !VALID_REGEX_FLAGS.include?(@args[1].value)
            errors << {
              token: @args.first,
              message: "Invalid Regex flag",
              status: :fatal,
              syntax: false,
              constraint: true
            }
          end

          begin
            Regexp.new(@args.first.value)
          rescue
            errors << {
              token: @args.first,
              message: "Invalid Regexp",
              status: :fatal,
              syntax: false,
              constraint: true
            }
          end

          errors
        end
      end
    end
  end
end
