module Sparkql
  module Nodes
    module Functions
      # arg1: TODO
      class Months < Function
        ARG_META = [
          {
            types: [:integer],
            allow_field: false,
          }
        ].freeze

        def arg_meta
          ARG_META
        end

        def return_type
          :datetime
        end
      end
    end
  end
end