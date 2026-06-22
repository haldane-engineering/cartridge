# frozen_string_literal: true

module CartridgeCore
  module Services
    module CacheActions
      class Load
        def self.apply!(*args) = new.apply(*args)

        def apply!(tree, tl_state)
          assign_timeline_attributes!(tl_state, tree)
          # assign timeline.tree_state
          tree_state_class = CartridgeCore::Entities::TreeState
          tree_state = tl_state.dig(:trees, tl_state[:head])
          tree.tree_state = tree_state_class.new(**tree_state.slice(tree_state_class.state_keys))
          # build state for each of the contained routes
          tree.routes.each do |route|
            route_slice_keys = tree_state.current.keys.keep_if { |k| k.to_s.include?(route.name.to_s) }
            route.tree_state = tree.tree_state.current.slice(*route_slice_keys)
          end
          tree
        end

        private

        def assign_timeline_attributes(tl_state, tree)
          # build the rest of the timeline associations (definitions, events, commits, trees, id, head, stop_pro)
          tl_state.keys.each do |tl_attribute|
            attribute_value = tl_state[tl_attribute]
            next timeline.send(:"#{tl_attribute_key}=", attribute_value) unless attribute_value.is_a?(Array)

            association_list = attribute_value.map do |assoc_entry|
              entity_for(tl_attribute_key).new(**assoc_entry)
            end
            tree.send(:"#{tl_attribute_key}=", association_list)
          end
        end

        # TODO: Move stop processes and scheduled executions to root folder
        def entity_for(key) = "::CartridgeCore::Entities::#{key.camelize.singularize}".constantize
      end
    end
  end
end
