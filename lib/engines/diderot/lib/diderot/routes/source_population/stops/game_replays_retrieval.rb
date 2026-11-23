# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Stops
        class GameReplaysRetrieval < Diderot::Routes::ApplicableStop
          def call
            available_games = provider.game_class.where(id: available_game_ids)
            # TODO: this stop should take a parameter specifying with replay source should be engaged
            # retrieve_source: :replay || :stream -> provider selects as fit.
            retrieve_urls = lambda { |game|
              ->(_, _) {
                provider.replay_url_retriever.call(game, provider:)
                changeset_concat(key: :downloaded_game_ids, value: game.id)
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
