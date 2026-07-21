# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Concerns
      module TreeState
        module CommitOperations
          def commit!(changeset, state, **commit_opts)
            ::CartridgeCore::Services::TreeState::CommittalService.new(self, changeset:, state:)
              .using_commit_opts(**commit_opts)
              .commit!
          end

          def build_tree_and_save!
            s_keys = %i(commits routes)
            routes = self.routes.each_with_object({}) { |route, sum| sum[route.name] = route.tree_state.current }
            self.head = tree_state[:head] # reassign tree head
            # assign the new state keys to the entity's tree
            s_keys.each { send(:"#{_1}=", send(_1).concat(tree_state.send(_1))) }
            # build new tree state
            timestamp = Time.zone.now.to_i
            state_meta_keys = %i(head current definition_id)
            persistable_tree = s_keys.index_with(&->(key) { tree_state.send(key).map(&:persistable_state) }).merge(
              parameters: context[:parameters], routes: routes, id: timestamp, **tree_state.to_h.slice(*state_meta_keys),
            )
            persist!(new_tree_state: persistable_tree)
          end

          def parent
            raise NotImplentedError
          end
        end
      end
    end
  end
end
