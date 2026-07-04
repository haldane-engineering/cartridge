# frozen_string_literal: true

module CartridgeCore
  module Services
    module CacheActions
      class Load
        TL_IDENTIFIER = 'id'

        def self.apply!(*args) = new.apply!(*args)

        def apply!(tree, tl_state)
          assign_timeline_attributes!(tl_state, tree)
          # Yep I understand that tree.trees is an etymological fallacy - please allow :)
          tree.tree_state = tree.trees.find(&->(tree) { tree.id == tl_state[:head].to_s })
          # build state for each of the contained routes
          tree.routes.each do |route|
            # To keep the routes and their contained stops completely isolated and independent of each other
            # We prepend the route name to the state entry key; such that when building the route we assert it's
            # appropriate state keys with a name check on each key.
            route_tree_state = tree.tree_state.dup
            route_slice_keys = tree.tree_state.current.keys.keep_if { |k| k.to_s.include?(route.name.to_s) }
            route_tree_state.current = tree.tree_state.current.slice(*route_slice_keys)
            route.tree_state = route_tree_state
          end
          tree
        end

        private

        def assign_timeline_attributes!(tl_state, timeline)
          # build the rest of the timeline associations (definitions, events, commits, trees, id, head, stop_pro)
          tl_state.keys.each do |tl_attribute_key|
            attribute_value = tl_state[tl_attribute_key]
            next timeline.send(:"#{tl_attribute_key}=", attribute_value) unless attribute_value.is_a?(Array)

            association_list = attribute_value.map do |assoc_entry|
              entity_for(tl_attribute_key.to_s).new(**assoc_entry)
            end
            timeline.send(:"#{tl_attribute_key}=", association_list)
          end
        end

        def entity_for(key)
          case key.to_sym
          when :trees then ::CartridgeCore::Entities::TreeState
          else "::CartridgeCore::Entities::#{key.singularize.camelize}".constantize
          end
        end
      end
    end
  end
end
