module Sparkql
  module Nodes
    class EqualityOperator < Operator
      SUPPORTED_TYPES = [:datetime, :date, :time, :character, :integer, :decimal, :shape, :boolean, :null, :function]

      def self.supported_types
        SUPPORTED_TYPES
      end
    end
  end
end
