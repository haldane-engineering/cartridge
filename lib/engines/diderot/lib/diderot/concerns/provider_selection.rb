# frozen_string_literal: true

module Diderot
  module Concerns
    module ProviderSelection
      PROVIDER_MAP = {
        nba: 'Diderot::Providers::Sportsradar::NBA',
      }.freeze

      def provider
        @provider ||= begin
          provider_type = route.context.parameters.dig(:provider_type)
          PROVIDER_MAP[provider_type.to_sym].constantize.new if provider_type
        rescue
          raise InvalidProviderError
        end
      end

      class InvalidProviderError < ArgumentError; end
    end
  end
end
