# frozen_string_literal: true

module CartridgeCore
  module Decorators
    module TreeState
      class CommitableEntityDecorator < SimpleDecorator
        delegate_all

        def assign_current_state_with_commit!(commit)
          entity.tree_state.head = commit.id
          entity.rree_state.current = commit.final_state
        end
      end
    end
  end
end
