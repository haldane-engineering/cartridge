# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Core
      class Stop
        class << self
          def call(*args) = new(*args).call

          # @param [Entities::TreeState] tree_state root/timeline tree state
          # @param [Entities::Route] the parent route
          # @param [Hash] opts including name and other relevant params
          def execute_with_changeset_in_context(tree_state, route, **opts)
            stop = new(tree_state, route, **opts)
            stop.call
          rescue StandardError => e
            require 'pry'
            binding.pry
            [nil, [*stop.errors, e]]
          end
        end

        attr_reader(*%i(tree_state route name changeset errors))

        def initialize(tree_state, route, **opts)
          @tree_state = tree_state
          @route = route
          @changeset = []
          @errors = []
          @name = opts[:name]
        end

        private

        # add other helper methods

        def respond_to_missing?(method_name,
          include_private = false)
          method_name.starts_with?('changeset_') || super
        end

        def method_missing(m_name, *args, **kwargs, &block)
          m_string = m_name.to_s
          if m_string.starts_with?('changeset_')
            strategy = m_string.delete_prefix('changeset_').to_sym
            changeset.push(::CartridgeCore::Entities::ChangeEntry.new(**kwargs.merge(strategy:)))
            [changeset, errors]
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
