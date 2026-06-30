# frozen_string_literal: true

module CartridgeCore
  module Entities
    CHANGE_KEYS = %i(version key strategy value application_index commit)
    ChangeEntry = Struct.new(*CHANGE_KEYS, keyword_init: true) do
      def invert_strategy!
        self.strategy = strategy_inverse_map.dig(strategy)
        self
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
