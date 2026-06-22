# frozen_string_literal: true

require 'sportsradar/provider'

module Diderot
  module Routes
    module SourcePopulation
      module Stops
        class TeamProfilesRetrieval < ::Diderot::Routes::ApplicableStop
          def call
            teams = ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql(
              <<~SQL,
                SELECT teams.id, count(memberships.id) as p_count
                from #{provider.team_class.table_name} teams
                inner join #{provider.team_membership_class.table_name} as memberships on memberships.team_id = teams.id
                group by teams.id
              SQL
            ))
            return changeset_add(key: :team_ids, value: teams.map(&:first)) if teams_already_populated?(teams)

            provider.fetch_teams.each do |team_json|
              populate_team_players!(provider.team_class.create!(
                **provider.formatter.team_attributes_from_json(team_json),
              ))
            end
            teams = provider.team_class.all
            # Populate the logos and player images
            spawn_processes!(
              [-> {
                Processes::TeamMembershipsProfilePopulationProcess.spawn!(teams, provider)
              }],
              blocking: false,
            )
            changeset_add(key: :team_ids, value: teams.ids)
          end

          private

          def teams_already_populated?(teams)
            team_membership_limit = ->(num) { num >= provider.settings.dig(:min_team_membership_count) }
            teams.count == provider.settings.dig(:exact_teams_count) && teams.map(&:last).all?(&team_membership_limit)
          end

          def populate_team_players!(team)
            provider.fetch_team_profile(team).dig(:players).each do |player_json|
              player_attributes = provider.formatter.player_attributes_from_json(player_json)
              player = provider.player_class.find_or_create_by(**player_attributes)
              provider.team_membership_class.create!(player:, team:)
            end
          end
        end
      end
    end
  end
end
