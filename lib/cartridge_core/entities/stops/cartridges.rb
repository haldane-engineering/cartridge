# frozen_string_literal: true

require 'cartridge_core/entities/execution_schedule'

module CartridgeCore
  module Entities
    module Stops
      module Cartridges
        # A collection of batteries-included extensions for stops. We chooseto include any of them by
        # appraising the workflow conf. stops with spawns_processes include the ProcessPropagation module
        # - stops with schedulable: true, include the ScheduleExecution module.
        module Enablement
          %i(spawns_processes schedules_execution).each do |enablement_name|
            define_method(:"#{enablement_name}?", &-> { __send__(enablement_name) })
          end
        end

        module ProcessProgagation
          def spawn_processes!(process_unit_blocks, **process_opts)
            # it is important that process_opts here contains the stop
            process_unit_opts = process_opts.delete(:unit_opts) || {}
            extra_process_opts = { id: SecureRandom.hex(8), route: }
            st_process = ::CartridgeCore::Entities::StopProcess.new(**process_opts.merge(extra_process_opts))
            process_unit_groups = process_unit_blocks.map do |pu_block|
              process_unit_meta = { id: SecureRandom.hex(8), stop_process_id: st_process.id, route: }
              process_unit = ::CartridgeCore::Entities::StopProcess::Unit.new(**process_unit_opts.merge(**process_unit_meta))
              [process_unit, ->() { pu_block.call(st_process, process_unit) }]
            end
            process_units = process_unit_groups.map(&:first)
            process_units.each(&:persist!)
            st_process.process_unit_ids = process_units.map(&:id)
            st_process.persist!
            # might need to pass a reconciler function in any case
            reconciler = ::CartridgeCore::Entities::Reconciler.new
            reconciler.concurrently_execute_with_reconciliation!(
              process_unit_groups.map(&:last),
              process_opts.fetch(:blocking, true),
            )
          end
        end

        module ScheduleExecution
          def schedule_timeline_execution!(context, executes_at:, halt_timeline:)
            # TODO: include leaf name as an add on module
            context = context.merge(parameters: route.context.parameters, stop: leaf_name, route: route.leaf_name)
            execution_args = {
              id:                 SecureRandom.hex(8),
              timeline_id:        route.timeline.id,
              serialized_context: context,
              status:             CartridgeCore::Entities::EXECUTION_SCHEDULE_STATUSES[:scheduled],
              executes_at:,
            }
            s_execution = ::CartridgeCore::Entities::ScheduledTimelineExecution.new(**execution_args)
            s_execution.persist!(route.timeline)
            params = { route:, stop: self, scheduled_execution: s_execution, scheduled_at: executes_at }
            scheduled_execution = ::CartridgeCore::Queueing::Worker.spawn!(
              ::CartridgeCore::Queueing::Worker::ExecutionContext.new(**params),
            )
            route.timeline.pause! if halt_timeline
            route.timeline.reload!
            scheduled_execution
          end
        end
      end
    end
  end
end
