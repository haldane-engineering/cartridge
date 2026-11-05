# frozen_string_literal: true

module Diderot
  module Providers
    module Services
      module Sportsradar
        module Nba
          class ResourceAssetsManager
            include Concerns::ExternalRequestCacheable

            def fetch_team_logo(team)
              t_resources = YAML.safe_load(retrieve_global_team_resources!)
              t_resources.find(&->(resource) { resource['name'] == team.name })&.dig('logo_url')
            end

            def fetch_player_image(player)
              player_resources = YAML.safe_load(retrieve_global_player_resources!)
              player_resources.find(&->(resource) {
                resource['first_name'] == player.first_name && resource['last_name'] == player.last_name
              })&.dig('image_url')
            end

            private

            def retrieve_global_player_resources!
              fetch_resources_with_cache!(
                'diderot.providers.sportsradar.players.resources',
                ENV.fetch('DIDEROT_NBA_PLAYERS_LOGOS_URL'),
              )
            end

            def retrieve_global_team_resources!
              fetch_resources_with_cache!(
                'diderot.providers.sportsradar.teams.resources',
                ENV.fetch('DIDEROT_NBA_TEAM_LOGOS_URL'),
              )
            end

            def fetch_resources_with_cache!(cache_key, uri)
              _, body = cache_request(cache_key, &->() { HTTParty.send(:get, URI(uri)) })
              body
            end

            def request_from_url(url, method:)
              "Net::HTTP::#{method.capitalize}".constantize.new(url)
            end
          end
        end
      end
    end
  end
end
