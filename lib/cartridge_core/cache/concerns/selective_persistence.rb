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
          key = self.class.index_key.to_sym
          record_set = route.timeline.send(key)
          index = record_set.find_index { |record| record.id == id }
          index ? record_set[index] = self : record_set.unshift(self)
          match = ->(r_json) { r_json.dig(:id) == id }
          route.timeline.tree_state.send(key).unshift({ id: }) unless route.timeline.tree_state.find(&match)
          route.timeline.persist!
        end

        # alias_method :as_json, :persistable_state
        # alias_method :to_json, :persistable_state

        private

        def cache
          @cache ||= CartridgeCore::ICache.new
        end

        module ClassMethods
          attr_reader :persistable_keys, index_key

          def persists!(*persistable_keys)
            @persistable_keys = persistable_keys
          end

          def index(index_key) = @index_key = index_key
        end
      end
    end
  end
end
