# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Stops
      module Cartridges
        module ProcessProgagation
          def spawn_processes!(process_unit_blocks, **process_opts)
            # it is important that process_opts here contains the stop
            process_unit_opts = process_opts.delete(:unit_opts)
            st_process = ::CartridgeCore::Entities::Stops::Process.new(**process_opts.merge(id: SecureRandom.hex(8)))
            process_units = process_unit_blocks.map do |pu_block|
              process_unit = ::CartridgeCore::Entities::Stops::Process::Unit.new(**process_unit_opts.merge(
                id: SecureRandom.hex(8), stop_process_id: st_process.id,
              ))
              [p_unit, ->() { pu_block.call(process, process_unit) }]
            end
            actors = process_units.map(&:last)
            process_units = process_units.map(&:first)
            # save the units - optimization (not sure how beneficial) but we could make one
            # call here instead to update (TODO)
            process_units.map(&:first).each(&:persist!)
            st_process.process_unit_ids = process_units.map(&:id)
            st_process.persist!
            # might need to pass a reconciler function in any case
            ::CartridgeCore::Entities::Reconciler.concurrently_execute_with_reconciliation!(
              actors,
              process_opts.fetch(:blocking, true),
            )
          end
        end

        module ScheduleExecution
          def schedule_timeline_execution!(context, at:, halt_timeline:)
            # TODO: include leaf name as an add on module
            s_exec = ::CartridgeCore::Entities::Stops::ScheduledExecution.new(
              id: SecureRandom.hex(8),
              timeline_id: route.timeline.id,
              serialized_context: context.merge(
                parameters: route.context.parameters,
                stop: leaf_name,
                route: route.leaf_name,
              ),
              executes_at: at,
            )
            s_exec.persist!
            timeline.pause! if halt_timeline
            timeline.reload!
          end
        end
      end
    end
  end
end
