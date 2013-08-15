module Sparkql
  module Geo
    class RecordRadius
      attr_accessor :record_id, :radius

      def initialize(record_id, radius)
        self.record_id = record_id
        self.radius = radius
      end
    end
  end
end
