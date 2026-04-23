# frozen_string_literal: true

module CartridgeCore
  module Cache
    module Concerns
      module SelectivePersistence
        def self.included(klass) = klass.extends(ClassMethods)

        def persistable_state
          self.class.persistable_keys.present? ? super.to_json.slice(*self.class.persistable_keys.map(&:to_s)) : super.to_json
        end

        alias_method :as_json, :persistable_state
        alias_method :to_json, :persistable_state

        private

        def cache
          @cache ||= CartridgeCore::ICache.new
        end

        module ClassMethods
          attr_reader :persistable_keys

          def persists!(*persistable_keys)
            @persistable_keys = persistable_keys
          end
        end
      end
    end
  end
end
