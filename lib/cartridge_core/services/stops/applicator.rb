# frozen_string_literal: true

module CartridgeCore
  module Services
    module Stops
      class Applicator < BaseService
        include ::CartridgeCore::Errors::DynamicPropagation

        def self.apply!(stop)
          new(stop).apply!
        end

        def initialize(stop)
          @stop = stop
        end

        def apply!
          # the goal of the applicator is to take in the tree state
          # it instantiates the relevant class -> and calls it with the tree state and full route
          # object -> expecting a change_set to be returned
          stop.route.register_activity!(stop, :stop_application_start)
          # apply checks run the checks -> these checks ensure that the required keys for
          # I can't seem to think of why a stop will need more than one check class -> one
          # check class should be able to make all the necessary sanity checks on the state but allow
          # TODO - stop checks should ensure that the parameters defined in the definitions yml are
          # present in the route's parameters.
          check_errors = stop.checks.map(&->(check) {
            check.validate_entity_state_with_changeset!(stop.route.tree_state)
          })
          return fail!(stop, :stop_application_error, check_errors.map(&:message)) if check_errors.any?

          # stop_class_here is the the stop defined in the main application -> e.g diderot::stops::available_games
          stop_class = stop.class_name.camelize.constantize
          stop_class.include(::CartridgeCore::Entities::Stops::Cartridges::ProcessPropagation) if stop.spawns_processes?
          stop_class.include(::CartridgeCore::Entities::Stops::Cartridges::ScheduleExecution) if stop.schedules_execution?
          # route.context.parameters.dig(stop.name) -> will yield list of passed params for the stop.
          changeset, errors = stop_class.apply_within_changeset_context(-> {
            stop_class.call(route.tree_state.current, route)
          })
          return fail!(stop, :stop_application_error, errors.map(&:message)) if errors.any?

          balancer_errors = populate_balancers(changeset).map(&:apply!)
          return fail!(stop, :stop_application_error, balancer_errors.map(&:message)) if balancer_errors.any?

          stop.using_context(context).assign_changeset(changeset)
        rescue NameError
          halt!(:missing_stop_applicator_error)
        ensure
          stop.route.register_activity!(stop, :stop_application_end)
        end

        private

        attr_reader :tree_state, :route, :stop

        def initialize_check(check_class)
          "#{stop.route.name.camelize}::Checks::#{check.camelize}".constantize.new(
            stop, stop.route.tree_state.current
          )
        end

        def populate_balancers(changeset)
          stop.balancers.map do |balancer_class|
            "#{stop.route.name.camelize}::Balancers::#{balancer_class.camelize}".constantize.new(
              stop, changeset
            )
          end
        end
      end
    end
  end
end
