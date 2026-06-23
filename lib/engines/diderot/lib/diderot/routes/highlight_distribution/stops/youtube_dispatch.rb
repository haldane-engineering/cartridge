# frozen_string_literal: true

module Diderot
  module Routes
    module HighlightDistribution
      module Stops
        class YoutubeDispatch < ::Diderot::Routes::ApplicableStop
          include Diderot::Concerns::CommandTools::Python

          def call
            available_games = provider.game_class.where(id: route_state_get(:available_game_ids))
            # wait for all cover images to be generated
            execute_cover_image_generation = ->(game) { ->() { Processes::CoverImageGeneration.spawn!(game, provider) } }
            spawn_processes!(available_games.map(&execute_cover_image_generation), blocking: true)
            distribution_execution_processes = available_games.map(&->(game) {
              lambda do
                provider.distribution_channels.each do |channel|
                  distribution, distribution_params = provider.distribution_parameters_from_game(game, channel:)
                  distribution.update!(status: :processing)
                  url, err, status = bin_exec(:"#{channel}_uploader", distribution_params.to_json)
                  next halt!(:video_distribution_error, err) unless status.success?

                  distribution.update!(status: :processed, url:)
                  changeset_concact(:distribution_ids, distribution.id)
                rescue
                  distribution.update!(status: :failed)
                  next
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
