module Sparkql
  module Nodes
    module Functions
      # arg1: TODO
      class Now < Function
        ARG_META = [].freeze

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
