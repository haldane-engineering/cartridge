# frozen_string_literal: true

module CartridgeCore
  module Entities
    EXECUTION_SCHEDULE_KEYS = %i(id route stop scheduled_at timeline_execution_id status)
    ExecutionSchedule = Struct.new(*EXECUTION_SCHEDULE_KEYS, keyword_init: true) do
      include CartridgeCore::Cache::Concerns::SelectivePersistence
      index(:execution_schedules)

      def queued?
        status.to_sym != :processed
      end

      def due?
        queued? && Time.zone.parse(scheduled_at).between?(1.minute.ago, 1.minute.from_now)
      end
    end
  end
end
