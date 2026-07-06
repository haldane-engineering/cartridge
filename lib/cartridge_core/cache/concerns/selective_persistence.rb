# frozen_string_literal: true

module CartridgeCore
  module Cache
    module Concerns
      module SelectivePersistence
        using CartridgeCore::Refinements::HashRefinement

        def self.included(klass)
          klass.extend(ClassMethods)
        end

        def persistable_state
          @persistable_state ||= begin
            root_state = self.class.persistable_keys.present? ? to_h.slice(*self.class.persistable_keys) : to_h
            root_state.deep_transform(&->(value) {
              value.respond_to?(:persistable_state) ? value.to_h.slice(*value.class.persistable_keys) : value
            })
          end
        end

        # def set(**attributes)
        #   attributes.entries { |(k, v)| send(:"#{k}=", v) }
        #   self
        # end

        def assign_attributes!(**attributes)
          attributes.entries.each do |(key, value)|
            send(:"#{key}=", value)
          end
          self
        end

        # This method exists for non-committal updates i.e. attributes that are not represented in the current
        # field (they do not update with commits!), they however update the version
        def persist!
          object_key = self.class.index_key.to_sym
          object_records = route.timeline.send(object_key)
          index = object_records.find_index { |record| record.id == id }
          index ? object_records[index] = self : object_records.unshift(self)
          state_entries = route.timeline.tree_state.send(object_key) || []
          # Don't save if it's already present
          state_entries.unshift({ id: }) unless state_entries.find(&->(r_json) { r_json.dig(:id) == id })
          tree_state_dup = route.timeline.tree_state.dup
          tree_state_dup.send(:"#{object_key}=", state_entries)
          # This is a suboptimal implementation, the initial plan was to always use a
          # commit to update tree state -> but I will refactor this method to take in
          # a version params which gets propagated as the head of the tree.
          # alternatively I could make the version optional.
          route.timeline.persist!(new_tree_state: tree_state_dup.to_h)
        end

        # alias_method :as_json, :persistable_state
        # alias_method :to_json, :persistable_state
        alias_method :set, :assign_attributes!

        private

        def cache
          @cache ||= CartridgeCore::ICache.new
        end

        module ClassMethods
          attr_reader :persistable_keys, :index_key

          def persists!(*persistable_keys)
            @persistable_keys = persistable_keys
          end

          def index(index_key) = @index_key = index_key
        end
      end
    end
  end
end
