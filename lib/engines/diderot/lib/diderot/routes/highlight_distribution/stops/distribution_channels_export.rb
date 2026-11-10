# frozen_string_literal: true

module Diderot
  module Routes
    module HighlightDistribution
      module Stops
        class DistributionChannelsExport < ::Diderot::Routes::ApplicableStop
          include Diderot::Concerns::CommandTools::Python

          def call
            available_games = provider.game_class.where(id: route_state_get(:available_game_ids))
            # wait for all cover images to be generated
            # We should move the cover image generation to a pre-stop hook. A check most likely, but that seems to
            # functionally differ from what's being described here.
            execute_cover_image_generation = ->(game) { ->() { Processes::CoverImageGeneration.spawn!(game, provider) } }
            spawn_processes!(available_games.map(&execute_cover_image_generation), blocking: true)
            distribution_execution_processes = available_games.map(&->(game) {
              lambda do
                provider.distribution_channels.each do |channel|
                  distribution, _ = provider.distribution_parameters_from_game(game, channel:)
                  ::Processes::DistributionChannelDispatch.spawn!(game, channel, provider)
                  distribution.reload!
                rescue ::Processes::DistributionChannelDispatch::ResourceUploadError => err
                  distribution.update!(status: :failed)
                  halt!(:video_distribution_error, err)
                end
              end
            })
            spawn_processes!(distribution_execution_processes, blocking: false)
          end
        end
      end
    end
  end
end
