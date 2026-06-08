# frozen_string_literal: true

module Diderot
  module Routes
    module HighlightDistribution
      module Processes
        class CoverImageGeneration < Diderot::Routes::ApplicableStop
          include Diderot::Concerns::CommandTools::Python

          # @param [NBA::Game] game
          # @param [Providers::Provider]
          def call(game, provider)
            # When we get games from any source the expectation is that the provider is able to
            # suggest two players from the 'warring' teams -> These two players should be of relevance to
            # the viewership and the game in context (players with the most impact (activity score) -e.g
            # in the NBA that would perhaps be the player with the most points. I think that's an implementation that's
            # not nuanced enough but works at the moment. Will implement. A more comprehensive and apposite implementation
            # will be scrubbing through the saved events and checking for the players with the most combined events (negative or positive)
            # just impact! TODO a bit later. I'm tired.

            # WORKFLOW
            # get the highlight video -> should be dist/{game_hash}/output.mp4
            # use commandtools to get a random section of the video, take screenshot
            # comb through the box score and find the players with the right external id
            # fetch their images -> per membership and turn to base 64
            # fetch the points_scored -> provider sends this from the box score json
            # convert to json
            path = game.output_video_path
            duration = %x(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 #{path})
            gap = rand(0..duration.to_i)
            py_exec("ffmpeg -ss #{gap} -i #{path} -vframes 1 -q:v 2 #{game.assets_directory}/background_cover.jpg")
            # game.participants always returns the away team first
            hero_player_external_ids = provider.infer_most_impactful_players(game)
            hero_player_photos = game.participants.zip(hero_player_external_ids).map(&->(team, player_external_id) {
              team.memberships.includes(:player).where(player: { external_id: player_external_id })
                                                .select(:photo_url).photo_url
            })
            background_image_base64 = Base64.strict_encode64(File.read(
              "#{game.assets_directory}/background_cover.jpg",
              mode: 'rb',
            ))
            league_image_base64 = game.league.logo_base64
            game_context = GameContext.new(
              destination: game.assets_directory,
              league_image_base64:,
              background_image_base64:,
            )
            url_to_base_64 = ->(url) { Base64.strict_encode64(Net::HTTP.get(URI(url))) }
            hero_images_64 = hero_player_photos.map(&url_to_base_64)
            participants = game.participants.zip(hero_images_64).map(&->((team, image64)) {
              points_scored = provider.infer_points_scored(game, team)
              GameParticipant.new(ticker: team.alias, name: team.full_name, hero_image_base64: image64, points_scored:)
            })
            image_generator_args = { participants:, game_context: }
            _, err, status = bin_exec(:cover_image_generator, JSON.stringify(image_generator_args))
            halt!(:cover_image_generation_error, err) unless status
          end

          GameContext = Struct.new(*%i(destination background_image_base64 league_image_base64), keyword_init: true)
          GameParticipant = Struct.new(*%i(team_ticker team_name hero_image_base64 total_points_scored))
        end
      end
    end
  end
end
