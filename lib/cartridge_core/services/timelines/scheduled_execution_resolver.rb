# frozen_string_literal: true

require 'cartridge_core/entities/execution_schedule'
module CartridgeCore
  module Services
    module Timelines
      class ScheduledExecutionResolver
        # include ::CartridgeCore::Services::Concerns::ConcurrentExecution

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
          }).dig(:execution_schedules)

          stored_executions = stored_executions.map(&->(execution_json) {
            ::CartridgeCore::Entities::ExecutionSchedule.new(**execution_json)
          }).first(1)

          actors = stored_executions.select(&:due?).map do |stored_execution|
            -> {
              begin
                timeline_execution = stored_execution.scheduled_timeline_execution
                force_timeline_id = '0c3b008b9a7341d8' # for testing.
                timeline_from_cache = cache.get(timeline: {
                  id:   timeline_execution.timeline_id || force_timeline_id,
                  type: :single,
                })

                timeline = Entities::Tree.new(**timeline_from_cache.dig(:timeline))
                definition = cache.get(definition: { id: timeline.definition_id, type: :single }).dig(:definition)

                definitions = [[timeline.key, JSON.parse(definition[:raw])]].to_h
                orchestrator_params = {
                  scheduled_timeline_execution: timeline_execution,
                  definitions:                  { timelines: definitions.deep_symbolize_keys },
                }

                timeline_key = timeline.key.to_sym
                ::CartridgeCore::Orchestrator.call(timeline_key, **orchestrator_params.merge(timeline.context.to_h))
                [timeline_execution, stored_execution].each { _1.set(status: :processed).persist!(timeline) }
              rescue
                [timeline_execution, stored_execution].each { _1.set(status: :failed).persist!(timeline) }
              end
            }
          end
          actors.each(&:call)
          # concurrently_execute_with_reconciliation!(actors, blocking: false)
        end

        # def resolve!(select_execution_ids)
        #   timeline_executions = cache.get(scheduled_timeline_executions:  {
        #     status: CartridgeCore::Entities::EXECUTION_SCHEDULE_STATUSES[:scheduled],
        #   }).dig(:scheduled_timeline_executions)

        #   timeline_executions = timeline_executions.map(&->(execution_json) {
        #     ::CartridgeCore::Entities::ScheduledTimelineExecution.new(**execution_json)
        #   })

        #   # TODO: Add group finders to redis adapter, so we can query directly for array inclusion.
        #   match = ->(execution) { select_execution_ids.include?(execution.id) }
        #   timeline_executions.select(&match).each do |execution|
        #     timeline = JSON.parse(cache.get({ timelines: { id: execution.timeline_id } }))
        #     ::CartridgeCore::Orchestrator(timeline.dig(:key), scheduled_timeline_execution: execution)
        #     execution.set(state: :processed).persist!
        #   end
        # end

        private

        def cache
          @cache ||= ::CartridgeCore::ICache.new
        end
      end
    end
  end
end
