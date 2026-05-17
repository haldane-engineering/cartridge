# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Stops
        class AvailableGamesRetrieval < ::Diderot::Routes::ApplicableStop
          def call
            available_games = provider.fetch_scheduled_games(route.context.parameters.dig(:date) || Time.zone.today)
            extract_game_id = ->(g_json) {
              provider.game_class.find_or_create_by(provider.formatter.game_attributes_from_json(g_json)).id
            }
            changeset_add(key: :available_game_ids, value: available_games.map(&extract_game_id))
          end
        end
      end
    end
  end
end
