# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Stops
        class TeamProfilesRetrieval < ::Diderot::Routes::ApplicableStop
          def call
            teams_ctx = ::Diderot::Routes::SourcePopulation::Services::CoreTeamRetrievalService.call(provider)
            return halt!(:team_profiles_retrieval_error, teams_ctx.errors) unless teams_ctx.success?

            spawn_processes!([-> { populate_memberships_with_context! }], blocking: false)
            changeset_add(key: :available_team_ids, value: teams_ctx.payload.map(&->(team_entry) { team_entry['id'] }))
          end

          private

          def populate_memberships_with_context!
            Processes::TeamMembershipsProfilePopulationProcess.spawn!(teams, provider)
          end
        end
      end
    end
  end
end
