# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Services
        class CoreTeamRetrievalService < BaseService
          TEAM_RETRIEVAL_BUFFER = 2.seconds

          def self.call(*args) = new(*args).call

          def initialize(provider)
            @provider = provider
          end

          # @param [::Diderot::Providers::Sportsradar::NBA]
          def call
            safely_execute do
              teams = fetch_teams_with_members
              provider.fetch_teams.each do |team_json|
                team = provider.team_class.find_or_create_by(**provider.formatter.team_attributes_from_json(team_json))
                next if team_already_populated?(team_json.merge(id: team.external_id).with_indifferent_access, teams:)

                populate_team_players!(team)
              rescue *provider.request_error_classes
                next
              ensure
                sleep provider.settings[:request_buffer] if provider.settings[:request_buffer]
              end
              context.succeed(teams)
            end
          end

          private

          attr_reader :provider

          def populate_team_players!(team)
            provider.fetch_team_players(team).each do |player_json|
              player_attributes = provider.formatter.player_attributes_from_json(player_json)
              player = provider.player_class.find_or_create_by(**player_attributes)
              provider.team_membership_class.create!(player:, team:)
            end
          end

          def team_already_populated?(team_json, teams:)
            teams.any?(&->(team_obj) {
              team_obj['external_id'] == team_json[provider.settings[:identifier_key]] &&
              provider.settings[:team_memberships_range].cover?(team_obj['player_count'])
            })
          end

          def fetch_teams_with_members
            ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql(
              <<~SQL,
                SELECT DISTINCT(teams.id), teams.external_id, teams.name, count(memberships.id) as player_count
                FROM #{provider.team_class.table_name} teams
                LEFT JOIN #{provider.team_membership_class.table_name} as memberships on teams.id = memberships.team_id
                GROUP BY teams.id
              SQL
            )).to_a
          end
        end
      end
    end
  end
end
