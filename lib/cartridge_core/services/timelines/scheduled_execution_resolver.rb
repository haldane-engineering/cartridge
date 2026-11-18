# frozen_string_literal: true

require 'cartridge_core/entities/execution_schedule'
module CartridgeCore
  module Services
    module Timelines
      class ScheduledExecutionResolver
        def start!
          task = Concurrent::TimerTask.new(execution_interval: 60, run_now: true) do
            run!
          end
          task.execute
          sleep while task.running?
        ensure
          task.shutdown
        end

        def run!
          stored_executions = cache.get(execution_schedules: {
            status: CartridgeCore::Entities::EXECUTION_SCHEDULE_STATUSES[:scheduled],
          })
          stored_executions = stored_executions.map(&->(execution_json) {
            ::CartridgeCore::Entities::ExecutionSchedule.new(**execution_json)
          })
          due_execution_ids = stored_executions.select(&:due?).map(&:timeline_execution_id)
          resolve!(due_execution_ids)
          stored_executions.each(&->(stored_execution) { stored_execution.set(state: :executed).persist! })
        end

        def resolve!(select_execution_ids)
          timeline_executions = cache.get(scheduled_timeline_executions:  {
            status: CartridgeCore::Entities::EXECUTION_SCHEDULE_STATUSES[:scheduled],
          })
          timeline_executions = timeline_executions.map(&->(execution_json) {
            ::CartridgeCore::Entities::ScheduledTimelineExecution.new(**execution_json)
          })
          # TODO: Add group finders to redis adapter, so we can query directly for array inclusion.
          match = ->(execution) { select_execution_ids.include?(execution.id) }
          timeline_executions.select(&match).each do |execution|
            timeline = JSON.parse(cache.get({ timelines: { id: execution.timeline_id } }))
            ::CartridgeCore::Orchestrator(timeline.dig(:key), scheduled_timeline_execution: execution)
            execution.set(state: :processed).persist!
          end
        end

        private

        def cache
          @cache ||= ::CartridgeCore::ICache.new
        end
      end
    end
  end
end
