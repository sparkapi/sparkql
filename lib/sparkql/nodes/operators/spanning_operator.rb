module Sparkql
  module Nodes
    class SpanningOperator < Operator
      SUPPORTED_TYPES = [:datetime, :date, :time, :integer, :decimal, :function]

      def self.supported_types
        SUPPORTED_TYPES
      end
    end
  end
end
