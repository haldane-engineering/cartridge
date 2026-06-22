# frozen_string_literal: true

module CartridgeCore
  module Services
    module TreeState
      class RollbackService < BaseService
        include ::CartridgeCore::Errors::DynamicPropagation

        def initialize(tree_state, **opts)
          @tree_state = tree_state
          ensure_options_validity!(opts)
          @to_commit, @steps, @should_undo = opts.values_at(%i(to_commit steps undo))
        end

        def apply!
          # logic here is quite straightforward:
          # if the caller requests (a) commit(s) undone -> then the commits are completely removed from the tree
          # state commit history and the values restored to pre-commit state. There is a bi-directional
          # propagation of the rollback or undoing i.e if the timeline's tree_state is asked to
          # rollback (or undo) a particular commit -> it first finds the stop and requests it to handle the action
          # it then progagates the changes/and the updated commits to it's own current state. Same principle if the caller
          # requests a roll back, but instead of removing the commit, we generate a rollback commit. Being
          # a new commit, it is added to the tree state's commit repository
          # but the head of the tree is not set to the commit's id, it is instead set to the preceeding commit's id.
          commit_index = steps || state.find_commit(to_commit, with_index: true).last
          reversible_commits = state.commits.slice(0, commit_index - 1) # state[:commit_index -1]
          applicable_changeset = reversible_commits.map(&:changeset).flat_map(&:invert_strategy!)
          reversible_commits.map(&:id).zip(applicable_changeset)
          merge_context = ::CartridgeCore::Services::TreeState::Merger.call(state, applicable_changeset)
          halt!(:changeset_merge_error, merge_context.errors.map(&:message)) unless merge_context.success?

          state.entity.commit!(
            applicable_changeset,
            merge_ctx.payload, # this is the new state
            rollback_state: should_undo ? :undo : :rollback,
            contains: reversible_commits,
          )
        end

        private

        attr_reader(*%i(tree_state to_commit opts should_undo))

        def ensure_options_validity!(opts)
          # only one of to_commit or steps can be provided
          executable_opts = %i(steps to_commit)
          # check that only one of the keys are contained
          if (executable_opts & opts.keys) == executable_opts || (steps && tree_state.commits.length < steps)
            halt!(:invalid_rollback_options_error)
          end
        end
      end
    end
  end
end
