# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Core
      class Stop
        def self.call(*args) = new(*args).call

        def initialize(tree_state, route, *args)
          @tree_state = tree_state
          @route = route
          @changeset = []
          @errors = []
        end

        def apply_within_changeset_context(&block)
          block.call
          [changeset, errors]
        # always fail silently
        rescue StandardError => e
          errors.push(e)
        end

        private

        attr_reader :tree_state, :route, :changeset, :errors

        # add other helper methods

        def respond_to_missing?(method_name, include_private = false) = method_name.starts_with?('changeset_') || super

        def method_missing(m_name, *args, **kwargs, &block)
          m_string = m_name.to_s
          if m_string.starts_with?('changeset_')
            strategy = m_string.delete_prefix('changeset_')
            changeset.push(::CatridgeCore::Entities::ChangeEntry.new(**kwargs.merge(strategy:)))
            changeset
          else
            super
          end
        end

        def capture_error(e) = errors.push(e)

        def route_state_get(key)
          # TODO: I do not need to split this key into the key parts
          route.timeline.reload!
          transform = ->(str) { str.split('::').last.underscore }
          route.tree_state.get("#{transform.call(route.name)}.#{transform.call(name)}.#{key}")
        end

        def state_get(key)
          # This method is useful for fetching state values which have been populated by other routes.
          # this is done after complete route traversal. For example in the poc, at the beginning of the
          # highlight composition route, it fetches the downloaded game ids from the previous route (source population).
          # but during it's own execution (which is pre-commital) it would fetch from it's internal route state using
          # #route_state_get
          route.timeline.reload!
          route.timeline.tree_state.get(key)
        end
      end
    end
  end
end
