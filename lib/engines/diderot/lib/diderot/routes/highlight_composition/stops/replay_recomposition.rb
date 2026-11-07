# frozen_string_literal: true

module Diderot
  module Routes
    module HighlightComposition
      module Stops
        class ReplayRecomposition < ::Diderot::Routes::ApplicableStop
          include Diderot::Concerns::CommandTools::Python

          FAILED_COMPOSED_VIDEOS_THRESHOLD = 0.5

          def call
            downloaded_game_ids = state_get(:downloaded_game_ids)
            logs = provider.game_log_class.where(game_id: state_get(:downloaded_game_ids))
            # TODO: Timestamp state changes -> i.e. when checking for downloaded game ids, it should
            # only check for videos populated today or else specified otherwise. But I think I already addressed this
            # with commits. Investigate
            composed_game_ids = state_get(:composed_game_ids) || []
            composable_game_ids = logs.map(&:game_id) - composed_game_ids
            composed_games_contexts = composable_game_ids.map do |game_id|
              ::Diderot::Routes::HighlightComposition::Services::ReplayCompositionService.call(
                game: provider.game_log_class.find_by(game_id: game_id),
                provider:,
              )
            end
            successfully_composed = composed_games_contexts.map(&:success?)
            failed_videos = composed_games_contexts.map(&:failed?)
            successfully_composed_game_ids = successfully_composed.map(&:payload)
            min_composed_videos = (downloaded_game_ids * FAILED_COMPOSED_VIDEOS_THRESHOLD).to_i
            if failed_videos.size >= min_composed_videos
              return halt!(:highlight_composition_error, failed_videos.map(&:errors).flat_map(&:to_s))
            end

            changeset_add(key: :composed_game_ids, value: successfully_composed_game_ids)
            changeset_add(
              key: :failed_games_in_composition,
              value: downloaded_game_ids - successfully_composed_game_ids,
            )
          end
        end
      end
    end
  end
end
