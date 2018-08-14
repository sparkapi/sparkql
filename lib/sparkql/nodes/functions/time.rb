module Sparkql
  module Nodes
    module Functions
      # arg1: TODO
      class Time < Function
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
          :time
        end
      end
    end
  end
end
