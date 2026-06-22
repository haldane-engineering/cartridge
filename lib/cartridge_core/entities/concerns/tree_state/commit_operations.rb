# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Concerns
      module TreeState
        module CommitOperations
          def commit!(changeset, state, **commit_opts)
            ::CartridgeCore::Services::TreeStates::CommittalService.new(self, changeset:, state:)
              .using_commit_opts(**commit_opts)
              .commit!
          end

          def build_tree_and_save!
            return unless is_a?(::CartridgeCore::Entities::Tree)

            s_keys = %i(commits head definition_id)
            routes = routes.each_with_object({}) { |route, sum| sum[route.name] = route.persistable_state }
            timestamp = Time.zone.now.to_i
            persistable_tree = s_keys.index_with(&->(key) { send(key) }).merge(
              parameters: context.parameters.persistable_state,
              routes: routes,
              current: tree_state.current,
            )
            persist!(timestamp, persistable_tree)
          end
        end
      end
    end
  end
end
