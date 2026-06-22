# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Stops
        class GameReplaysRetrieval < Diderot::Routes::ApplicableStop
          def call
            available_game_ids = route_state_get(:available_game_ids)
            date = route.context.parameters.dig(:date) || Time.now.in_time_zone(provider.time_zone)
            available_games = provider.game_class.where(id: available_game_ids)
            retrieve_urls = lambda { |game|
              ->() {
                provider.replay_url_retriever.call(game, date, stop:)
                changeset_concact(key: :downloaded_game_ids, value: game.id)
              }
            }
            # the assumption here is that every game is completed at the same time which is obviously a false assumption
            spawn_processes!(available_games.map(&retrieve_urls), blocking: true)
          end
        end
      end
    end
  end
end
