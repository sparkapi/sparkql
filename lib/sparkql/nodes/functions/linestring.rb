module Sparkql
  module Nodes
    module Functions
      # arg1: TODO
      class Linestring < Function
        ARG_META = [
          {
            types: [:character],
            allow_field: false,
          }
        ].freeze

        def arg_meta
          ARG_META
        end

        def return_type
          :shape
        end
      end
    end
  end
end
