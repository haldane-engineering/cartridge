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
        end

        def run!
          # fetch the scheduled_executions in the cache
          # load the timeline
          cache = ::CartridgeCore::ICache.new
          # TODO: delegate root_get
          executions = cache.root_get(:scheduled_executions, ::CartridgeCore::Entities::Timelines::ScheduledExecution)
          match = ->(execution) {
            execution.queued? && Time.zone.parse(execution.executes_at).between?(1.minute.ago, 1.minute.from_now)
          }
          executions.select(&match).each do |execution|
            timeline = JSON.parse(cache.get({ timelines: { id: execution.timeline_id } }))
            ::CartridgeCore::Orchestrator(timeline.dig(:key), scheduled_execution: execution)
            execution.set(state: :processed).persist!
          end
        end
      end
    end
  end
end
