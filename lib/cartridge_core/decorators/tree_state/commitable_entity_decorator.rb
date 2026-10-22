# frozen_string_literal: true

module CartridgeCore
  module Decorators
    module TreeState
      class CommitableEntityDecorator < SimpleDecorator
        delegate_all

        def assign_current_state_with_commit!(commit)
          entity.tree_state.head = commit.id
          entity.tree_state.current = commit.final_state
        end

        def commitable_name
          @commitable_name ||= object.is_a?(::CartridgeCore::Entities::Route) && full_commit_name_using_route
        end

        delegate :parent, to: :object

        private

        def full_commit_name_using_route
          # the commiting stop must be available in context
          @full_commit_name_using_route ||= "ro_#{name}.st_#{context.stop.name.underscore}"
        end
      end
    end
  end
end
