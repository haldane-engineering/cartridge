# frozen_string_literal: true

module CartridgeCore
  module Services
    module TreeState
      class CommittalService < Services::Base
        COMMIT_PREFIX = 'xC'

        def initialize(entity, changeset:, state:)
          @entity = ::CartridgeCore::Decorators::TreeState::CommitableEntityDecorator.decorate(entity)
          @changeset = changeset
          @new_state = state
        end

        def using_commit_opts(**commit_opts)
          @commit_opts = commit_opts
          @commit_id = commit_opts[:id]
          self
        end

        # #commit transposes the new_state to the old_state, it also generates and persists a new commit with the
        # sent changeset.
        # assuming you have an entity with current_state -> { a_xc34380xh: :b, b_xc1234dkndo: {c: :d} }
        # changeset with -> [{ key: :c, strategy: :add, value: :arbitrary_value},
        # { key: :b_xc1234dkndo, strategy: :merge, value:  {f: :g} }], the merge service should have generated the
        # updated state after changeset application. #commit (1) First goes through the new state and synchronizes
        # the new state keys, ensuring that each one is consistent with the pattern ro_route_name_st_stop_name
        # then (2) generates the actual commit entity, stores the original_state (entity.tree_state.current),
        # and then merges the updated state with the current, it then prepends the commit_id the changeset-contained keys in the
        # now merged state -> resulting in the final state. it then assigns that to the commits final state and updates the entity
        # current_state with the commit's final state, finally pushing the commit into the entity's commit bucket.
        def commit!
          original_tree_state = entity.tree_state.current
          commit_id = @commit_id || "xC#{SecureRandom.hex(8)}"
          # when rolling back -> if the rollback is missing an undo qualifier, then generate a new rollback commit
          # else find the preceeding commit to the last contained commit
          commit = if rollback_is_an_undo_action?
            commit = entity.tree_state.preceeding_commit_for(commit_opts.dig(:contains).last)
            commit.assign_attributes!(**commit_opts)
          else
            ::CartridgeCore::Entities::TreeStates::Commit.new(**commit_opts.merge(id: commit_id, changeset: changeset))
          end
          commit.assign_original_state!(original_tree_state)
          # first rebuild mergeable state
          # { a: :b, b_deleted: :a} -> { video_retrival_a: :b, video_retrieval_b_deleted: :a }
          commitable_state = new_state.keys.each_with_object({}) do |key, n_state|
            # prefix the name of the committing entity to the store key
            # this has to be conditional -> if the name already includes the full
            # commitable name then return as is -> else prepend the commitable_name
            next n_state[key] = new_state[key] if key.to_s.include?(entity.commitable_name)

            n_state[:"#{entity.commitable_name}_#{key}"] = new_state[key]
          end

          commitable_state = original_tree_state.merge(commitable_state)
          pre_commit_assignment_state = commitable_state.dup
          #  changeset.keys -> ["_entity_name_actual_key_name_cX"].
          #  During the merge, the old values should already be replaced
          # in the commitable state -> so you just need to find the value and reassign with
          # the new commit id -> all commits start with xC092234934
          changeset.map(&:key).each do |change_entry_key|
            s_key, _ = tree_state_entry_for(change_entry_key, pre_commit_assignment_state)
            pre_commit_assignment_state[:"#{original_key_for(s_key.to_s)}_#{commit.id}"] =
              pre_commit_assignment_state.delete(s_key)
          end

          commit.assign_final_state!(pre_commit_assignment_state)
          # commit.current_state { ...former_state_keys, **new_state_keys}
          # push the commit into the entity's applied commits bucket
          entity.tree_state.apply_commit!(commit)
          if entity.respond_to?(:parent)
            # use the dummy object pattern to handle this nil condition
            entity.parent.tree_state.apply_commit!(commit)
            # map the new current state to the trees entry
            # build the persistable state and save to cache
            entity.parent.build_tree_and_save!
          end
        end

        private

        attr_reader :state, :changeset, :new_state, :commit_opts, :entity

        def tree_state_entry_for(target_key, tree_state)
          current_key = tree_state.keys.find do |key|
            key.to_s.include?(target_key.to_s)
          end
          [current_key, tree_state[current_key]]
        end

        def rollback_is_an_undo_action?
          commit_opts&.dig(:rollback_state) == :undo
        end

        # @param [Symbol] state_key
        # @return [String]
        def original_key_for(state_key)
          # Each state entry key should have a commit id suffixed to it e.g available_team_ids_0x123456 -> so to extract the original state key
          # we can confidently split the string and rejoin without the suffix
          key_parts = state_key.split('_')
          commit_suffix = key_parts[key_parts.length - 1]
          state_key = state_key.tr("_#{commit_suffix}") if commit_suffix.starts_with?(COMMIT_PREFIX)
          state_key
        end
      end
    end
  end
end
