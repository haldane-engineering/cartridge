# frozen_string_literal: true

module Diderot
  module Routes
    module HighlightDistribution
      module Processes
        class DistributionChannelDispatch
          include Diderot::Concerns::CommandTools::Python

          def self.spawn!(*args) = new.spawn!(*args)

          # @param [::Diderot::Nba::Game] game, the game to be uploaded
          # @param [Symbol] channel, one of %i(youtube tiktok instagram)
          # @provider [::Diderot::Providers::Base]
          def spawn!(game, channel, provider)
            ActiveRecord::Base.transaction do
              @game = game
              distribution_args = { resource: game, status: :initialized, league: game.league, platform_type: channel }
              @distribution = ::Diderot::PlatformDistribution.create!(**distribution_args)
              distribution_params = provider.distribution_parameters_from_game(@game, channel:)
              @distribution.update!(status: :processing, metadata: distribution_params.to_json)
              url, err, status = pybin_exec(:"#{channel}_uploader", stdin: distribution_params.to_json)
              raise ResourceUploadError, err unless status.success?

              @distribution.update!(status: :processed, url:)
            end
          end

          class ResourceUploadError < StandardError; end
        end
      end
    end
  end
end
