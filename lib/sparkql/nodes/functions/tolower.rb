module Sparkql
  module Nodes
    module Functions
      # arg1: TODO
      class Tolower < Function
        ARG_META = [
          {
            types: [:character],
            allow_field: true,
          }
        ].freeze

        def arg_meta
          ARG_META
        end

        def return_type
          :character
        end
      end
    end
  end
end
