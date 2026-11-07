# frozen_string_literal: true

module Diderot
  module Routes
    module HighlightDistribution
      module Processes
        class CoverImageGeneration
          include Diderot::Concerns::CommandTools::Python
          include ::Diderot::Concerns::ExternalRequestable

          def self.spawn!(*args) = new.spawn!(*args)

          # @param [NBA::Game] game
          # @param [Providers::Provider]
          def spawn!(game, provider)
            # When we get games from any source the expectation is that the provider is able to
            # suggest two players from the facing teams -> These two players should be of relevance to
            # the viewership and the game in context (players with the most impact (activity score) -e.g
            # in the NBA that would perhaps be the player with the most points. I think that's an implementation that's
            # not nuanced enough but works at the moment. Will implement. A more comprehensive and apposite implementation
            # will be scrubbing through the saved events and checking for the players with the most combined events (negative or positive)
            # just impact! TODO a bit later. I'm tired.

            # WORKFLOW
            # get the highlight video -> should be dest/{game_hash}/output.mp4
            # use commandtools to get a random section of the video, take screenshot
            # comb through the box score and find the players with the right external id
            # fetch their images -> per membership and turn to base 64
            # fetch the points_scored -> provider sends this from the box score json
            # convert to json
            @game = game
            @provider = provider
            hero_player_external_ids = provider.infer_most_impactful_players(game)
            hero_player_photos = game.participants.zip(hero_player_external_ids).map(&->((team, player_external_id)) {
              team.memberships.includes(:player).where(player: { external_id: player_external_id })
               .select(*%i(player_id photo_url)).first&.photo_url
            })
            game_context = GameContext.new(**game_context_params)
            hero_images_64 = hero_player_photos.map(&method(:image_url_to_base64))
            participants = game.participants.zip(hero_images_64).map(&->((team, image64)) {
              GameParticipant.new(**game_participant_args(team, image64))
            })
            image_generator_args = { participants:, game_context: }
            _, err, status = pybin_exec(:cover_image_generator, stdin: image_generator_args.to_json)
            halt!(:cover_image_generation_error, err) unless status
          end

          private

          GameContext = Struct.new(
            *%i(destination background_image_base64 league_image_base64 game_scheduled_at),
            keyword_init: true,
          )
          GameParticipant = Struct.new(
            *%i(team_ticker team_name hero_image_base64 total_points_scored),
            keyword_init: true,
          )

          def image_url_to_base64(url)
            response = Net::HTTP.get_response(
              URI.parse(url),
              { 'User-Agent' => 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:31.0) Gecko/20100101 Firefox/31.0' },
            )
            Base64.strict_encode64(response.body)
          end

          def game_context_params
            @game_context_params ||= begin
              bg_base64 = Base64.strict_encode64(File.read("#{@game.assets_directory}/probe.png", mode: 'rb'))
              {
                destination:             @game.assets_directory,
                league_image_base64:     @game.league.logo_base64,
                background_image_base64: bg_base64,
                game_scheduled_at:       @game.scheduled_at.strftime('%B %d, %Y').upcase,
              }
            end
          end

          def game_participant_args(team, image64)
            {
              team_ticker:         team.alias,
              team_name:           team.full_name,
              hero_image_base64:   image64,
              total_points_scored: @provider.infer_points_scored(@game, team),
            }
          end
        end
      end
    end
  end
end
