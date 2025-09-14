# frozen_string_literal: true

module Timelines
  module Models
    Event = Struct.new(*%i(created_at event_type event_context timeline_id id), keyword_init: true) do
      def persist!
        self.id = "tl-#{timeline.id}.evt_#{SecureRandom.hex(8)}"
        Rails.cache.write(id, as_json)
      end

      # def self.for(object )
        
      # end
    end
  end
end
