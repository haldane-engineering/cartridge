# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Processes
        class TeamMembershipsProfilePopulationProcess
          def spawn!(teams, provider)
            actors = teams.map(&->(team) { provider.decorators[:team].decorate(team) }).map do |team|
              ->() {
                url = provider.images_provider.fetch_team_logo(team.full_name.tr(' ', '_'))
                team.update(logo_url: url) # Expectation is that all teams should have the attribute 'logo_url'
                # update the memberships
                team.memberships.each(&->(membership) {
                  f_name = membership.player.full_name.tr(' ', '_')
                  membership.update(photo_url: provider.images_provider.fetch_player_image(f_name))
                })
              }
            end
            pool = Concurrent::FixedThreadPool.call(actors.count)
            promises = actors.map { |actor| Concurrent::Promises.future(executor: pool, &actor) }
            Concurrent::Promises.zip(*promises).value!
          end
        end
      end
    end
  end
end
