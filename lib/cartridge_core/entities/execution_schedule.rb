# frozen_string_literal: true

module CartridgeCore
  module Entities
    EXECUTION_SCHEDULE_KEYS = %i(id route stop scheduled_at timeline_execution_id status)
    EXECUTION_SCHEDULE_STATUSES = %i(scheduled processing processed failed).index_with(&:itself)

    ExecutionSchedule = Struct.new(*EXECUTION_SCHEDULE_KEYS, keyword_init: true) do
      include CartridgeCore::Cache::Concerns::SelectivePersistence
      index(:execution_schedules)

      def queued?
        status.to_sym != :processed
      end

      def due?
        return true
        queued? && Time.zone.parse(scheduled_at).between?(1.minute.ago, 1.minute.from_now)
      end

      # @param [::CartridgeCore::ICache] cache - the cache handler
      # @return [::CartridgeCore::Entities::ScheduledTimelineExecution]
      def scheduled_timeline_execution(cache = ::CartridgeCore::ICache.new)
        @scheduled_timeline_execution ||= begin
          t_execution = cache.get(scheduled_timeline_execution:
            { id: timeline_execution_id, type: :single }).dig(:scheduled_timeline_execution)
          ::CartridgeCore::Entities::ScheduledTimelineExecution.new(**t_execution) if t_execution
        end
      end
    end
  end
end
