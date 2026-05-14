# frozen_string_literal: true

require 'sportsradar/provider'
# require_relative '../../../../../../../cartridge_core/entities/core/stop'

module Diderot
  module Routes
    module SourcePopulation
      module Stops
        class TeamProfilesRetrieval < ::CartridgeCore::Entities::Core::Stop
          def call
            teams = ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql(
              <<~SQL,
                SELECT teams.id, count(memberships.id) as p_count
                from diderot_teams as teams
                inner join diderot_team_memberships as memberships on memberships.team_id = teams.id
                group by teams.id
              SQL
            ))
            return changeset_add(key: :team_ids, value: teams.map(&:first)) if teams_already_populated?(teams)

            provider.fetch_nba_teams.each do |team_json|
              populate_team_players!(::Diderot::Team.create!(**provider.formatter.team_attributes_from_json(team_json)))
            end
            changeset_add(key: :team_ids, value: ::Diderot::Team.all.ids)
          rescue ActiveRecord::RecordInvalid, SportsRadar::Provider::FetchError => e
            capture_error(e)
          end

          private

          def provider = @provider ||= ::SportsRadar::Provider.new

          def teams_already_populated?(teams)
            settings = { exact_teams_count: 30, min_team_membership_count: 12 }
            team_membership_limit = ->(num) { num >= settings.dig(:min_team_membership_count) }
            teams.count == settings.dig(:exact_teams_count) && teams.map(&:last).all?(&team_membership_limit)
          end

          def populate_team_players!
            provider.fetch_team_profile(team).dig(:players).each do |player_json|
              player = ::Diderot::Player.find_or_create_by(**provider.formatter.player_attributes_from_json(player_json))
              ::Diderot::Teams::Membership.create!(player:, team:)
            end
          end
        end
      end
    end
  end
end
