# frozen_string_literal: true

module Providers
  module SportsRadar
    class NBA
      CONFIG_KEYS = %i(team_class player_class team_membership_class game_class settings timezone).freeze
      HIGHLIGHTABLE_EVENT_TYPES = %w(twopointmade threepointmade).freeze
      def fetch_teams
        response = exec_request(URI("#{configuration.settings.dig(:base_url)}/league/teams.json"))
        JSON.parse(response)
      end

      def fetch_team_profile(team)
        path = "league/teams/#{team.external_id}/profile.json"
        response = exec_request(URI("#{configuration.settings.dig(:base_url)}/#{path}"))
        JSON.parse(response)
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

      def formatter = Formatter.new

      def configuration
        @configuration ||= ProviderConfiguration.new(
          team_class: ::Diderot::NBA::Team,
          player_class: ::Diderot::NBA::Player,
          team_membership_class: ::Diderot::NBA::TeamMembership,
          game_class: ::Dideror::NBA::Game.includes(*%i(home_team away_team)),
          game_log_class: ::Diderot::NBA::GameLog,
          persistable_game_log_event_types: %w(lineupchange),
          settings:,
          timezone: 'US/Eastern',
        )
      end

      delegate(*CONFIG_KEYS, to: :configuration)

      private

      def exec_request(url, body)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        request = request_from_url(url)
        http.request(request).read_body
      end

      def request_from_url(url)
        Net::HTTP::Get.new(url).tap do |request|
          request['x-api-key'] = configuration.dig(:api_key)
          request['Content-Type'] = 'application/json'
        end
      end

      def settings
        @settings ||= {
          # store the api key securely
          api_key:                   'bKSHi5kiycfpXyjiHpDTRpHN6qq0oFUYrEbWmxfU',
          base_url:                  'https://api.sportradar.com/nba/trial/v8/en',
          access_level:              :trial,
          identifier_key:            'id',
          exact_teams_count:         30,
          min_team_membership_count: 12,
        }
      end

      def highlightable_event_types = HIGHLIGHTABLE_EVENT_TYPES

      class Formatter
        def team_attributes_from_json(team_json)
          external_id = team_json.delete(configuration.settings.dig(:identifier_key))
          persistable_json = team_json.slice(*::Diderot::NBA::Team.attribute_names).compact
          persistable_json.merge(external_id:)
        end

        def player_attributes_from_json(player_json)
          external_id = player_json.delete(configuration.settings.dig(:identifier_key))
          persistable_json = player_json.slice(*::Diderot::NBA::Player.attribute_names).compact
          persistable_json.merge(external_id:)
        end

        def game_attributes_from_json(game_json)
          game_json.slice(*Diderot::NBA::Game.attribute_names).compact.merge(
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
          )
        end

        def game_log_attributes_from_json(game_log_json, game)
          external_id = game_log_json.delete(configuration.settings.dig(:identifier_key))
          match_relevant_events = ->(event) {
            configuration.settings.dig(:persistable_game_log_event_types).include?(event['event_type'])
          }
          game_log_json.slice(*Diderot::NBA::GameLog.attribute_names).merge(
            game_id: game.id,
            raw_json: game_log_json.merge(events: game_log_json.dig('events').select(&match_relevant_events)),
            external_id:,
          )
        end

        def internal_team_id_for(external_team_id) = ::Diderot::NBA::Team.find_by!(external_id: external_team_id)
      end

      ProviderConfiguration = Struct.new(*CONFIG_KEYS, keyword_init: true)
    end
  end
end
