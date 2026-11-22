# frozen_string_literal: true

module Diderot
  module Routes
    module SourcePopulation
      module Stops
        class TeamProfilesRetrieval < ::Diderot::Routes::ApplicableStop
          def call
            #  to skip step 1 - Ideal process will be to add a skip step in the in context.parameters - really exciting!
            # changeset_add(key: :available_team_ids, value: provider.team_class.ids)
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
