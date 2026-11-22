# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Stops
        class AvailableGamesScheduling < Diderot::Routes::ApplicableStop
          LOG_AVAILABILITY_BUFFER = 20.minutes
          REPLAY_AVAILABILITY_BUFFER = 10.minutes # start streaming 10 minutes early.

          def call
            game_class = previously_scheduled_date? ? provider.game_class : provider.game_class.unplayed
            available_game_ids = route_state_get(:game_availabilities)[date_in_context.to_s]
            available_games = game_class.where(id: available_game_ids)
            return changeset_add(
              key: :available_game_ids,
              value: available_game_ids,
            ) if previously_scheduled_date?

            # games retrieved are played at different times -> first the replay, then the logs are available
            # 15-20 minutes after the game is done. We wait for 20 minutes -- such that we are able to predictably
            # release videos ~30 minutes after the game is completed.
            # At the moment we have to assume that each game is about 2:30 minutes. We'll keep it at 3 hours.
            # and spinoff workers 10 minutes after that threshold to get the game logs.
            # (they won't be available immediately after the game ended)
            #
            # schedule_streaming_replays! and logs!
            scheduled_game_execution_ids = available_games.map.with_index do |game, g_index|
              # Start the replay retrieval service 10 minutes before the game starts.
              replay_retrieval_context = {
                game_id:      game.id,
                scheduled_at: game.scheduled_at - REPLAY_AVAILABILITY_BUFFER,
              }
              # then 20 minutes after the game is ended, stream the logs.
              log_retrieval_schedule_at = game.scheduled_at + provider.approximate_game_length + LOG_AVAILABILITY_BUFFER
              logs_retrieval_context = replay_retrieval_context.merge(scheduled_at: log_retrieval_schedule_at)
              [replay_retrieval_context, logs_retrieval_context].map(&->(ctx) {
                # pause execution at the last game for the day.
                exec_ctx = { executes_at: ctx[:scheduled_at], halt_timeline: g_index == available_games.length - 1 }
                schedule_timeline_execution!(ctx, **exec_ctx).id
              })
            end

            changeset_add(key: :scheduled_game_execution_ids, value: scheduled_game_execution_ids)
          end
        end
      end
    end
  end
end
