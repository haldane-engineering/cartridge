# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Stops
        class TeamProfilesRetrieval < ::Diderot::Routes::ApplicableStop
          def call
            # take the first 5 for now
            provider.fetch_teams.slice(0, 5).each do |team_json|
              provider.team_class.find_or_create_by(**provider.formatter.team_attributes_from_json(team_json)).tap do |team|
                populate_team_players!(team)
              end unless team_already_populated?(team_json)
            end
            spawn_processes!([-> { populate_memberships_with_context! }], blocking: false)
            changeset_add(key: :available_team_ids, value: teams.ids)
          end

          private

          def team_already_populated?(team_json)
            teams_with_members_count.any?(&->(team_obj) {
              team_obj['external_id'] == team_json[provider.settings[:identifier_key]] &&
              provider.settings[:team_memberships_range].cover?(team_obj['player_count'])
            })
          end

          def populate_memberships_with_context!
            Processes::TeamMembershipsProfilePopulationProcess.spawn!(teams, provider)
          end

          def populate_team_players!(team)
            provider.fetch_team_players(team).each do |player_json|
              player_attributes = provider.formatter.player_attributes_from_json(player_json)
              player = provider.player_class.find_or_create_by(**player_attributes)
              provider.team_membership_class.create!(player:, team:)
            end
            sleep provider.settings[:request_buffer] if provider.settings[:request_buffer]
          end

          def teams_with_members_count
            @teams_with_members_count ||= ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql(
              <<~SQL,
                SELECT DISTINCT(teams.id), teams.external_id, count(memberships.id) as player_count
                FROM #{provider.team_class.table_name} teams
                INNER JOIN #{provider.team_membership_class.table_name} as memberships on memberships.team_id = teams.id
                GROUP BY teams.id
              SQL
            )).to_a
          end
        end
      end
    end
  end
end
