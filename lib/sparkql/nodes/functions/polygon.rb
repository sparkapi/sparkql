module Sparkql
  module Nodes
    module Functions
      # arg1: TODO
      class Polygon < Function
        ARG_META = [
          {
            types: [:character],
            allow_field: false,
          }
        ].freeze

        def arg_meta
          ARG_META
        end
      end
    end
  end
end
