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
              ActiveRecord::Base.transaction do
                game_pbp = provider.fetch_game_play_by_play(game)
                game_log_attributes = provider.formatter.game_log_attributes_from_json(game_pbp)
                game_box_score = provider.fetch_game_box_score(game)
                box_score_attributes = provider.formatter.box_score_attributes_from_json(game_box_score)
                game_log = provider.game_log_class.create!(**game_log_attributes.merge(box_score: box_score_attributes))
                game.update(game_log_id: game_log.id)
              end
            end
            changeset_add(
              key: :game_log_ids,
              value: provider.game_log_class.where(game_id: available_game_ids).ids,
            )
          end
        end
      end
    end
  end
end
