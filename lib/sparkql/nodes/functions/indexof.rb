module Sparkql
  module Nodes
    module Functions
      # arg1: TODO
      class Indexof < Function
        ARG_META = [
          {
            types: [:character],
            allow_field: true,
          },
          {
            types: [:character],
            allow_field: false,
          }
        ].freeze

        def arg_meta
          ARG_META
        end

        def return_type
          :integer
        end
      end
    end
  end
end
