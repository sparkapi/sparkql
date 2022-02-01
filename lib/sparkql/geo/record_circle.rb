module Sparkql
  module Geo
    class RecordRadius
      RECORD_ID_REGEX = /\A[0-9]{26}\z/.freeze

      attr_accessor :record_id, :radius

      def self.valid_record_id?(record_id)
        record_id =~ RECORD_ID_REGEX
      end

      def initialize(record_id, radius)
        self.record_id = record_id
        self.radius = radius
      end
    end
  end
end
