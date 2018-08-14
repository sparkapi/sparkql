module Sparkql
  module Nodes
    module Functions
      # arg1: TODO
      class Startswith < Function
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
          :eq_builder
        end
      end
    end
  end
end
