# frozen_string_literal: true

module Diderot
  module Concerns
    module ProviderSelection
      PROVIDER_MAP = {
        nba: 'Providers::SportsRadar::NBA',
      }.freeze

      def provider
        @provider ||= begin
          provider_type = route.context.parameters.dig(:provider_type)
          raise InvalidProviderError unless PROVIDER_MAP.key?(provider_type.to_sym)

          PROVIDER_MAP.dig(route.context.parameters.dig(provider_type.to_sym)).constantize.new
        end
      end

      class InvalidProviderError < ArgumentError; end
    end
  end
end
