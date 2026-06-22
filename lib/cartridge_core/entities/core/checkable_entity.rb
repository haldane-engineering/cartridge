# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Core
      # include SimpleDecorator
      class CheckableEntity < SimpleDecorator
        delegate_all

        # TODO: - will have to refactor all of this branch logic
        # into their own classes
        def current_tree_state
          @current_tree_state ||= if object.is_a(Models::Route)
            object.current
          elsif object.is_a(Models::Stop)
            route.current
          end
        end

        # change name
        # should return a list of applied steps [:source_population, :games_retrieval]
        def applied
          @applied_steps ||= if object.is_a?(Models::Route)
            current_tree_state.applied_routes
          elsif object.is_a?(Models::Stop)
            route.applied_stops
          end
        end

        def preceeding_index = index - 1

        def next_index = index + 1

        def preceeding_step
          @preceeding_step = if object.is_a?(::Entities::Route)
            timeline.list_routes[preceeding_index]
          elsif object.is_a?(Models::Stop)
            route.list_stops[preceeding_index]
          end
        end
      end
    end
  end
end
