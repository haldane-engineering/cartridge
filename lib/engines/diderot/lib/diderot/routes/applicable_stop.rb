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
    end
  end
end
