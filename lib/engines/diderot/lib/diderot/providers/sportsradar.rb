# frozen_string_literal: true

module Diderot
  module Providers
    module Sportsradar
      class NBA
        include Concerns::ExternalRequestCacheable

        CONFIG_KEYS = %i(
          team_class
          player_class
          team_membership_class
          game_class
          settings
          timezone
          images_provider
          decorators
          game_log_class
        ).freeze
        DISTRIBUTION_CHANNELS = %i(youtube).index_with(&:itself)
        HIGHLIGHTABLE_EVENT_TYPES = %w(twopointmade threepointmade).freeze

        # rubocop:disable Style/ClassMethodsDefinitions
        def self.league
          @league ||= ::Diderot::Leagues::Nba.first
        end
        # rubocop:enable Style/ClassMethodsDefinitions

        def fetch_teams
          response = exec_request(URI("#{configuration.settings.dig(:base_url)}/league/teams.json"))
          JSON.parse(response).dig('teams')
        end

        def fetch_team_players(team)
          path = "teams/#{team.external_id}/profile.json"
          response = exec_request(URI("#{configuration.settings.dig(:base_url)}/#{path}"))
          JSON.parse(response)['players']
        end

        def fetch_scheduled_games(date)
          formatted_date = date.strftime('%Y/%m/%d')
          response = exec_request(URI("#{configuration.settings.dig(:base_url)}/games/#{formatted_date}/schedule.json"))
          JSON.parse(response)
        end

        def fetch_game_play_by_play(game)
          response = exec_request(URI("#{configuration.settings.dig(:base_url)}/games/#{game.external_id}/pbp.json"))
          JSON.parse(response)
        end

        def fetch_game_box_score(game)
          response = exec_request(URI("#{configuration.settings.dig(:base_url)}/games/#{game.external_id}/boxscore.json"))
          JSON.parse(response)
        end

        def generate_highlight_fragments(events, fragment_class)
          events = events.select(&->(event) { highlightable_event_types.include?(event['event_type']) })
          # This is not a correct implementation - we should use the time diff between the game start time
          # and the time in the execution context
          prefix_padding = ->(time_string, gap) { Time.zone.parse(time_string) - gap }
          affix_padding = ->(time_string, gap) { Time.zone.parse(time_string) + gap }
          events.map do |event|
            fragment_class.new(
              title: event['description'],
              start: prefix_padding.call(event['wall_clock'], configuration.events_prefix_gap.minutes),
              end: affix_padding.call(event['wall_clock'], configuration.events_suffix_gap.minutes),
            )
          end
        end

        # @param [Diderot::Nba::Game] game - well, the game in context
        # @return [Array<String>] the sportsradar id of the highest scorers
        def infer_most_impactful_players(game)
          # Again this is a naive implementation of this algorithm (IMHO). We're (simply) getting the player
          # who's scored the most points. I expounded on a better approach in the cover image generation process.
          # Anyway, we've been proovided the (scoring, assists and rebound) leaders by sportsradar in the boxscore attribute.
          # see https://developer.sportradar.com/basketball/reference/nba-game-boxscore
          point_leaders = game.game_log.box_score.slice(*%w(away home)).values.pluck(%w(leaders points))
          point_leaders.flatten.pluck('id') # ID from sportsradar
        end

        # @param [Diderot::Nba::Game] game (in context)
        # @param [Diderot::Nba::Team] team (in context)
        def infer_points_scored(game, team)
          match_team = ->(team_box_score) { team_box_score['id'] == team.external_id }
          # game.participants returns the away team first.
          game.game_log.box_score.slice(*%w(away home)).values(&match_team)['points']
        end

        def formatter = Formatter.new(configuration)

        def configuration
          @configuration ||= ProviderConfiguration.new(
            team_class: ::Diderot::Nba::Team,
            player_class: ::Diderot::Nba::Player,
            team_membership_class: ::Diderot::Nba::TeamMembership,
            game_class: ::Diderot::Nba::Game.includes(*%i(home_team away_team)),
            game_log_class: ::Diderot::Nba::GameLog,
            settings: {
              # store the api key securely
              api_key:                   '9LWpuAoFoIkMm6bikYW5Qn4GKK8qacXzKJ1nejGy',
              base_url:                  'https://api.sportradar.com/nba/trial/v8/en',
              access_level:              :trial,
              identifier_key:            'id',
              exact_teams_count:         30,
              min_team_membership_count: 12,
              request_buffer:            10.seconds,
              # TODO: - find the league defined values for this.
              team_memberships_range:    (12..50),
            },
            timezone: 'US/Eastern',
            images_provider: ::Diderot::Providers::Images::Sportsdb.new,
            decorators: {
              team: ::Nba::TeamDecorator,
            },
          )
        end

        def distribution_channels = DISTRIBUTION_CHANNELS.keys

        def distribution_parameters_from_game(game, channel:)
          return DistributionParameters::Youtube.extract(game) if youtube_distribution?(channel)

          raise NotImplementedError
        end

        delegate(*CONFIG_KEYS, to: :configuration)

        private

        # @param [String] uri - well, the uri.
        # @param [Hash] body
        # @return [String] the response json
        def exec_request(uri, body = {}, **opts)
          opts = api_request_defaults.merge(opts)
          Rails.logger.info([uri, body, opts])
          cache_key = [uri, body, opts].map(&:to_json).join('|')
          success, body = cache_request(cache_key, &-> {
            HTTParty.send(opts[:method], uri, opts.slice(:headers))
          })
          raise(ProviderTransportError, body) unless success

          body
        end

        def body_includable?(method) = %i(post put).include?(method)

        def api_request_defaults
          @api_request_defaults ||= {
            method:       :get,
            headers:      {
              'Content-Type': 'application/json',
              'x-api-key':    configuration.settings.dig(:api_key),
            },
            include_body: false,
          }
        end

        def youtube_distribution?(channel) = channel == :youtube

        def highlightable_event_types = HIGHLIGHTABLE_EVENT_TYPES

        # TODO: refactor to own file
        class Formatter
          def initialize(configuration)
            @configuration = configuration
          end

          def box_score_attributes_from_json(box_score_json)
            persistable_keys = %w(name market id scoring leaders assists alias points)
            team_box_scores = box_score_json.slice(*%w(home away))
            team_box_scores.entries.map(&->((k, v)) { [k, v.slice(*persistable_keys)] }).to_h
          end

          def team_attributes_from_json(team_json)
            external_id = team_json.delete(configuration.settings.dig(:identifier_key))
            persistable_json = team_json.slice(*::Diderot::Nba::Team.attribute_names).compact
            persistable_json.merge(external_id:, league_id: ::Diderot::Leagues::Nba.league_id)
          end

          def player_attributes_from_json(player_json)
            external_id = player_json.delete(configuration.settings.dig(:identifier_key))
            persistable_json = player_json.slice(*::Diderot::Nba::Player.attribute_names).compact
            persistable_json.merge(external_id:, league_id: ::Diderot::Leagues::Nba.league_id)
          end

          def game_attributes_from_json(game_json)
            game_json.slice(*Diderot::Nba::Game.attribute_names).compact.merge(
              scheduled_at: game_json['scheduled'],
              external_id: game_json['id'],
              external_reference_id: game_json['sr_id'],
              away_timezone: game_json.dig(*%w(time_zones away)),
              home_timezone: game_json.dig(*%w(time_zones home)),
              season_type: game_json.dig(*%w(season type)),
              season_year: game_json.dig(*%w(season year)),
              venue_name: game_json.dig(*%w(venue name)),
              home_team_id: internal_team_id_for(game_json.dig(*%w(home id))),
              away_team_id: internal_team_id_for(game_json.dig(*%w(away id))),
              league_id: ::Diderot::Leagues::Nba.league_id,
              metadata: { special_context_title: 'Full Highlights' },
            )
          end

          def game_log_attributes_from_json(game_log_json, game)
            external_id = game_log_json.delete(configuration.settings.dig(:identifier_key))
            match_relevant_events = ->(event) {
              configuration.settings.dig(:persistable_game_log_event_types).include?(event['event_type'])
            }
            game_log_json.slice(*Diderot::Nba::GameLog.attribute_names).merge(
              game_id: game.id,
              raw_json: game_log_json.merge(events: game_log_json.dig('events').select(&match_relevant_events)),
              external_id:,
            )
          end

          def internal_team_id_for(external_team_id) = ::Diderot::Nba::Team.find_by!(external_id: external_team_id)

          private

          attr_reader :configuration
        end

        ProviderConfiguration = Struct.new(*CONFIG_KEYS, keyword_init: true)

        module DistributionParameters
          YT_KEYS = %i(file_path title description category keywords privacy_status).freeze
          Youtube = Struct.new(*YT_KEYS, keyword_init: true) do
            class << self
              def game_specific_keys = %i(file_path title description)
              def league_specific_keys = YT_KEYS - game_specific_keys
              def name = :youtube

              def title_components(game)
                [
                  game.participants.map(&:full_name).join(' vs '),
                  game.meta('special_context.title'), # e.g Nba finals will have special context 'Nba Finals Game 1'
                  "| #{game.scheduled_at.strftime("%B %-d, %Y")}",
                ].join(', ')
              end

              def extract!(game)
                new(**league_specific_keys.index_with(&->(key) {
                  game.league.meta("distributions.youtube.#{key}")
                }).merge(
                  **game_specific_keys.index_with(&->(key) { game.meta("distributions.youtube.#{key}") }),
                  file_path: game.output_video_path,
                  # e.g San Antonio Spurs vs New York Knicks Full Game 2 Highlights - June 5, 2026 | Nba Finals
                  title: title_components(game),
                ))
              end
            end
          end
        end

        class ProviderTransportError < StandardError; end
      end
    end
  end
end
