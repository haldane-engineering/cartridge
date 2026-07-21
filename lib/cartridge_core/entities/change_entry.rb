# frozen_string_literal: true

module CartridgeCore
  module Entities
    STRATEGY_QUESTIONABLE = '?'

    CHANGE_KEYS = %i(version key strategy value application_index commit applied)
    ChangeEntry = Struct.new(*CHANGE_KEYS, keyword_init: true) do
      def invert_strategy!
        self.strategy = strategy_inverse_map.dig(strategy)
        self
      end

      def respond_to_missing?(method_name, include_private = true)
        strategy_inverse_map.keys.any? { method_name.to_s.include?(_1.to_s) }
      end

      def method_missing(method_name, *args)
        return super unless strategy_inverse_map.keys.any? { method_name.to_s.include?(_1.to_s) }

        strategy.to_s == method_name.to_s.tr('?', '')
      end

      private

      def strategy_inverse_map
        @strategy_inverse_map ||= {
          add:     :remove,
          merge:   :split,
          push:    :pop,
          concact: :slice,
          remove:  :add,
        }
      end
    end
  end
end
