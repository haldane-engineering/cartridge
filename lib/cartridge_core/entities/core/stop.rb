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
          transform = ->(str) { str.split('::').last.underscore }
          route.tree_state.get("#{transform.call(route.name)}.#{transform.call(name)}.#{key}")
        end
      end
    end
  end
end
