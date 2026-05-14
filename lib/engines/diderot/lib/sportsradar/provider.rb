# frozen_string_literal: true

module SportsRadar
  class Provider
    def fetch_nba_teams
      response = exec_request(URI("#{configuration.dig(:base_url)}/league/teams.json"))
      JSON.parse(response)
    end

    def fetch_team_profile(team)
      response = exec_request(URI("#{configuration.dig(:base_url)}/league/teams/#{team.external_id}/profile.json"))
      JSON.parse(response)
    end

    def formatter = Formatter.new

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

    def configuration
      @configuration ||= {
        # remember to store the api key securely
        api_key:        'bKSHi5kiycfpXyjiHpDTRpHN6qq0oFUYrEbWmxfU',
        base_url:       'https://api.sportradar.com/nba/trial/v8/en',
        access_level:   :trial,
        identifier_key: 'id',
      }
    end

    class Formatter
      def team_attributes_from_json(team_json)
        external_id = team_json.delete(configuration.dig(:identifier_key))
        persistable_json = team_json.slice(*::Diderot::Team.attribute_names).compact
        persistable_json.merge(external_id:)
      end

      def player_attributes_from_json(player_json)
        external_id = player_json.delete(configuration.dig(:identifier_key))
        persistable_json = player_json.slice(*::Diderot::Player.attribute_names).compact
        persistable_json.merge(external_id:)
      end
    end
  end
end
