# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Stops
        class AvailableGamesRetrieval < ::Diderot::Routes::ApplicableStop
          def call
            available_games = provider.fetch_scheduled_games(date_in_context)
            extract_game_id = ->(g_json) {
              provider.game_class.find_or_create_by!(
                provider.formatter.game_attributes_from_json(g_json)
                .except(*%w(id)),
              ).id
            }
            game_ids = available_games.map(&extract_game_id)
            changeset_merge(key: :game_availabilities, value: [[date_in_context.to_s, game_ids]].to_h)
          end
        end
      end
    end
  end
end
