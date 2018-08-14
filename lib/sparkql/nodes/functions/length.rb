module Sparkql
  module Nodes
    module Functions
      # arg1: TODO
      class Length < Function
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
          :integer
        end
      end
    end
  end
end
