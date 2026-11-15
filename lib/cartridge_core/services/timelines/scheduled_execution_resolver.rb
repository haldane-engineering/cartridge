# frozen_string_literal: true

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
          stored_executions = cache.root_get(:execution_schedules, ::CartridgeCore::Entities::ExecutionSchedule).select(&:due?)
          resolve!(stored_executions.map(&:timeline_execution_id))
          stored_executions.each(&->(stored_execution) { stored_execution.set(state: :executed).persist! })
        end

        def resolve!(select_execution_ids)
          executions = cache.root_get(:scheduled_timeline_executions, ::CartridgeCore::Entities::ScheduledTimelineExecution)
          match = ->(execution) { select_execution_ids.include?(execution.id) }
          executions.select(&match).each do |execution|
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
