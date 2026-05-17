# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Stops
        class GameLogsRetrieval < ::Diderot::Routes::ApplicableStop
          def call
            # before this stop is run -> it has to check that this is present in state
            # ensure that this is defined in the orchestration.yml, available game ids is populate
            # by the preceeding step (AvailableGamesRetrieval)
            available_game_ids = route_state_get(:available_game_ids)
            provider.game_class.where(id: available_game_ids).find_each do |game|
              provider.game_log_class.create!(provider.formatter.game_log_attributes_from_json(
                provider.fetch_game_play_by_play(game),
                game,
              ))
            end
            changeset_add(key: :game_log_ids, value: provider.game_log_class.where(game_id: available_game_ids).ids)
          end
        end
      end
    end
  end
end
