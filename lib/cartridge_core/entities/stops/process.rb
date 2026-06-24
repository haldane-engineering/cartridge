# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Stops
      Process = Struct.new(
        *%i(status stop_name timeline_id observable_state_key process_unit_ids id blocking expected_units_count route),
        keyword_init: true,
      ) do
        include CartridgeCore::Cache::Concerns::SelectivePersistence

        def persist!
          index = route.timeline.stop_processes.find_index { |st_process| st_process.id == id }
          index ? route.timeline.stop_processes[index] = self : route.timeline.stop_processes.unshift(self)
          match = ->(process_json) { process_json[:id] == id }
          route.timeline.tree_state.stop_processes.unshift({ id: }) unless route.timeline.tree_state.find(&match)
          route.timeline.persist!
        end

        self::Unit = Struct.new(*%i(
          id
          actual_completion_value
          expected_completion_value
          metadata
          stop_process_id
          route
          state_entry_value
        )) do
          include CartridgeCore::Cache::Concerns::SelectivePersistence

          def persist!
            index = route.timeline.stop_process_units.find_index { |process_unit| process_unit.id == id }
            index ? route.timeline.stop_process_units[index] = self : route.timeline.stop_process_units.unshift(self)
            route.timeline.persist!
          end
        end
      end
    end
  end
end
