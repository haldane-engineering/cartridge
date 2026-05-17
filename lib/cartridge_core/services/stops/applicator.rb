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
          check_errors = stop.checks(&method(:initialize_check)).map(&:apply!)
          return fail!(stop, :stop_application_error, check_errors.map(&:message)) if check_errors.any?

          # stop_class_here is the the stop defined in the main application -> e.g diderot::stops::available_games
          stop_class = "#{route.name}/#{stop.name}".camelize.constantize
          stop_class.include(ProcessPropagation) if stop.spawns_processes?
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

        module ProcessProgagation
          def spawn_process!(process_unit_blocks, **process_opts)
            # it is important that process_opts here contains the stop
            process_unit_opts = process_opts.delete(:unit_opts)
            st_process = ::CatridgeCore::Entities::Stops::Process.new(**process_opts.merge(id: SecureRandom.hex(8)))
            process_units = process_unit_blocks.map do |pu_block|
              process_unit = ::CartridgeCore::Entities::Stops::Process::Unit.new(**process_unit_opts.merge(
                id: SecureRandom.hex(8), stop_process_id: st_process.id,
              ))
              [p_unit, ->() { pu_block.call(process, process_unit) }]
            end
            actors = process_units.map(&:last)
            process_units = process_units.map(&:first)
            # save the units - optimization (not sure how beneficial) but we could make one
            # call here instead to update (TODO)
            process_units.map(&:first).each(&:persist!)
            st_process.process_unit_ids = process_units.map(&:id)
            st_process.persist!
            # might need to pass a reconciler function in any case
            ::CartridgeCore::Entities::Reconciler.concurrently_execute_with_reconciliation!(
              actors,
              process_opts.fetch(:blocking, true),
            )
          end
        end
      end
    end
  end
end
