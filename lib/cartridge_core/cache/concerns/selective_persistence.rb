# frozen_string_literal: true

module CartridgeCore
  module Cache
    module Concerns
      module SelectivePersistence
        def self.included(klass) = klass.extend(ClassMethods)

        def persistable_state
          self.class.persistable_keys.present? ? as_json.slice(*self.class.persistable_keys.map(&:to_s)) : as_json
        end

        def set(**attributes)
          attributes.entries { |(k, v)| send(:"#{k}=", v) }
          self
        end

        def persist!
          object_key = self.class.index_key.to_sym
          object_records = route.timeline.send(object_key)
          index = object_records.find_index { |record| record.id == id }
          index ? object_records[index] = self : object_records.unshift(self)
          match = ->(r_json) { r_json.dig(:id) == id }
          state_entries = route.timeline.tree_state.send(object_key) || []
          state_entries.unshift({ id: }) unless state_entries.find(&match)
          route.timeline.tree_state.send(:"#{object_key}=", state_entries)
          # This is a suboptimal implementation, the initial plan was to always use a
          # commit to update tree state -> but I will refactor this method to take in
          # a version params which gets propagated as the head of the tree.
          # alternatively I could make the version optional.
          version_signature = Digest::SHA256.hexdigest(route.timeline.tree_state.as_json)[(0..8)]
          route.timeline.persist!(version_signature)
        end

        # alias_method :as_json, :persistable_state
        # alias_method :to_json, :persistable_state

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
