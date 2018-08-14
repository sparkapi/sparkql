module Sparkql
  module Nodes
    module Functions
      # arg1: TODO
      class Date < Function
        ARG_META = [
          {
            types: [:datetime, :date],
            allow_field: true,
          }
        ].freeze

        def arg_meta
          ARG_META
        end

        def return_type
          :date
        end
      end
    end
  end
end
