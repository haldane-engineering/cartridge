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

        def commitable_name
           # Commitable name is the name of the commiting class underscored
          # and the entity type prefixed. Might be sensible to include the timeline key as well
          @commitable_name ||= object.is_a?(::CartridgeCore::Entities::Route) && "ro_#{name}"
        end

        delegate :parent, to: :object
      end
    end
  end
end
