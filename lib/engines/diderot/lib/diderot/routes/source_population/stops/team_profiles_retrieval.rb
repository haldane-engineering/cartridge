# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Stops
        class TeamProfilesRetrieval < ::Diderot::Routes::ApplicableStop
          def call
            # teams = ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql(
            #   <<~SQL,
            #     SELECT teams.id, count(memberships.id) as p_count
            #     from #{provider.team_class.table_name} teams
            #     inner join #{provider.team_membership_class.table_name} as memberships on memberships.team_id = teams.id
            #     group by teams.id
            #   SQL
            # ))
            available_teams_in_state = route_state_get(:available_team_ids)
            provider.fetch_teams.each do |team_json|
              team = provider.team_class.find_or_create_by(
                **provider.formatter.team_attributes_from_json(team_json),
              )
              populate_team_players!(team)
              changeset_add(key: :available_team_ids, value: [*available_teams_in_state, team.id])
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
            provider.fetch_team_players(team).each do |player_json|
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
