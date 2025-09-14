# frozen_string_literal: true

module Timelines
  class Orchestrator < BaseService
    class Errors; def self.list = []; end

    def initialize(timeline, **_opts)
      @timeline = timeline
    end

    def call
      # take the timeline name
      timeline = Timeline::Builder.build(timeline)
      # build the time line tree
      # loop through the routes using the sequence
      # for each route -> first run the check through the tree state
      # check it has everything it needs
      # for each route -> establish its section on the timeline tree
      # send a copy of the tree state -> to the the route
      # route then loops through all the stops, again using the sequence
      # sends copies of the state to each of the stops -> it first runs the checks (as well)
      # each stop takes the state-> does what it needs to do #process? method -> then releases
      # the former state, changeset, and new state(?)
      # when all the stop processes have been run, each of the changesets are collated and applied
      # on the tree state (copy with the parent route)/ and the balancer runs and makes sure the expected keys are present/absent/
      # and the changes make sense.  the list of changes from each entire route,
      #  are returned as a payload to the orchestrator -> orchestrator "merges" in the changes to the tree state,
      #  after taking a version snapshot, and also saves the diffs in a way that the changes could be played back
      # for each unit of the sequence
      sort_routes_by_sequence(timeline.routes).map do |route|
        # have an exact snapshot of when the route is applied
        tree.register_activity!(route, :route_application_start) # remember that at this point route could also be [1,2]
        # get all the check classes -> make sure they validate the state such that they contain
        # all the keys that are required for the route to run
        check_klasses = [tree_checks.using].flat_map(&:camelize).map(&:constantize)
        check_klasses.reduce(route.checks.changeset) do |check, changeset_sum|
          tree.register_activity!(check, :check_application_start)
          changeset_sum = check.apply_validation_using_changeset!(changeset_sum, timeline.tree_state)
          tree.register_activity!(check, :check_application_end)
          changeset_sum
        end
        #  Ideally the check classes throw an error if missing so rescue
        changeset, context, errors = if route.is_a?(Timelines::Models::Route)
          route.traverse!(timeline.tree_state)
        else
          concurrently_traverse_routes_with_reconciliation!(
            route,
            state: timeline.tree_state,
          )
        end

        raise_error!(errors) if errors.present?

        # after the balancers are done running # merge the state changes
        balancers = [tree.balancers.using].flat_map(&:camelize).map(&:constantize)
        balancers.reduce(route.balancers.changeset) do |balancer, changeset_sum|
          tree.register_activity!(balancer, :balancer_application_start)
          changeset_sum = balancer.compare_and_balance_changeset_with_state!(changeset_sum, timeline.tree_state)
          tree.register_activity!(balancer, :balancer_application_end)
          changeset_sum
        end

        # have an exact snapshot of when the route is applied
        tree.register_activity!(route, :route_application_end)

        # this is the core of the whole application here -> merging changes
        # involves applying the matching the expected changeset keys for each route
        # creating a new copy of state and applying the updates to that new version
        # the old version is cached with it's version id (which is a concactenation of the names of applied steps at that point)
        # the new version is then set as the new state -> timeline.tree_state should return a new version of the
        # state on every
        timeline.merge!(changeset, context, route:)
        next changeset, context
        # apply balances
      end
    end
  rescue *::Timelines::Orchestrator::Errors.list
    raise_error!(:process_error) # for now
  ensure
    timeline.snapshot!
  end

  private

  attr_reader :timeline

  def concurrently_traverse_routes_with_reconciliation!(route, tree_state:)
    reconciler = timeline.with_route(route).reconciler
    # set the current route in context - like with OperatorAware
    reconciler.concurrently_apply!(route, tree_state:)
  end

  def source_routes_by_sequence(routes)
    return routes if timeline.sequence.empty?

    timeline.sequence.map do |entry_index|
      next routes[entry_index] unless entry_index.is_a?(Array)

      entry_index.map { |index| timeline.routes[index] }
    end
  end
end
