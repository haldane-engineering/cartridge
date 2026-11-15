# frozen_string_literal: true

module CartridgeCore
  module Services
    module Timelines
      class ScheduledExecutionScheduler
        # We take the context from the caller and create the execution schedule, our resolver checks for
        # due schedules, fetches the timeline execution id and executes the contained timeline execution.
        #
        # @param [Symbol] timeline_execution_id
        # @param [::CartridgeCore::Entities::Route] route - the caller route
        # @param [::CartridgeCore::Entities::Stop] stop - the caller stop
        # @param [Timestamp] scheduled_at
        def perform(timeline_execution_id, route, stop, scheduled_at)
          CartridgeCore::Entities::ExecutionSchedule.new(
            route: route.name,
            stop: stop.name,
            timeline_execution_id:,
            scheduled_at:,
          ).persist!
        end
      end
    end
  end
end
