# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Processes
        class TeamMembershipsProfilePopulationProcess
          def self.spawn!(*args) = new.spawn!(*args)

          def spawn!(teams, provider)
            teams.find_each do |team|
              url = provider.images_provider.fetch_team_logo(team)
              team.update(logo_url: url)
              team.memberships.where(photo_url: nil).find_each(&->(membership) {
                membership.update(photo_url: provider.images_provider.fetch_player_image(membership.player))
              })
            end
          end
        end
      end
    end
  end
end
