# frozen_string_literal: true

module Diderot
  module Providers
    module Images
      class Sportsdb
        include Concerns::ExternalRequestable

        def fetch_team_logo(full_name)
          # http://thesportsdb.com/api/v1/json/123/searchteams.php?t=Arsenal
          resp = exec_request("#{setting[:teams_url]}?t=#{full_name}", nil, method: :get)
          resp.last.dig('teams', 0, 'strBadge')
        end

        def fetch_player_image(full_name)
          resp = exec_request("#{setting[:players_url]}?t=#{full_name}", nil, method: :get)
          resp[setting[:player_image_key]]
        end

        private

        def setting
          @setting ||= {
            teams_url:        "https://www.thesportsdb.com/api/v1/json/#{api_key}/searchteams.php",
            team_logo_key:    'strBadge',
            players_url:      "https://www.thesportsdb.com/api/v1/json/#{api_key}/searchplayers.php",
            player_image_key: 'strThumb',
          }
        end

        def api_key = ENV.fetch('SPORTSDB_API_KEY', '123')

        def remote_players_yml = ENV.fetch('DIDEROT_REMOTE_PLAYERS_YML_URL', 'https://app.shareotter.com/files/Ufu1NXtRZSJ9iaMjvldV')
      end
    end
  end
end
