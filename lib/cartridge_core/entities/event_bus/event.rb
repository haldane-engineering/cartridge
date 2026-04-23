# frozen_string_literal: true

module CartridgeCore
  module Entities
    module EventBus
      EVENT_KEYS = %i(title metadata executor actor timestamp key timeline_id)
      Event = Struct.new(EVENT_KEYS, keyword_init: true) do
        include ::CartridgeCore::Cache::Concerns::SelectivePersistence
        persists!(*EVENT_KEYS)
      end
    end
  end
end
