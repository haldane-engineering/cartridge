# frozen_string_literal: true

module Diderot
  module Routes
    class ApplicableStop < ::CartridgeCore::Entities::Core::Stop
      include ::Diderot::Concerns::ProviderSelection

      def leaf_name
        @leaf_name ||= name.split('::').last.underscore
      end

      private

      def date_in_context
        @date_in_context ||= route.context.parameters.dig(:date) || Time.zone.today
      end

      def previously_scheduled_date?
        date_in_context < Time.zone.today
      end

      def available_game_ids
        # retrieves the game scheduled for processing from the scheduled execution state -> takes precedence.
        game_id_in_ctx = route.context.execution_context.try(*%i(dig game_id))
        game_id_in_ctx ? [game_id_in_ctx] : route_state_get(:game_availabilities)[date_in_context.to_s]
      end
    end
  end
end
