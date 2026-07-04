# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Stops
      module Cartridges
        module Enablement
          %i(spawns_processes schedules_execution).each do |enablement_name|
            define_method(:"#{enablement_name}?", &->() { __send__(enablement_name) })
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
            ::CartridgeCore::Entities::Reconciler.concurrently_execute_with_reconciliation!(
              process_units_groups.map(&:last),
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
              executes_at:,
            }
            ::CartridgeCore::Entities::ScheduledTimelineExecution.new(**execution_args).tap(&:persist!)
            timeline.pause! if halt_timeline
            timeline.reload!
          end
        end
      end
    end
  end
end
