# frozen_string_literal: true

module CartridgeCore
  class Orchestrator
    include ::CartridgeCore::Errors::DynamicPropagation

    def self.call(key, **opts) = new(key, **opts).call

    def initialize(timeline_key, **opts)
      @timeline_key = timeline_key
      @opts = opts
    end

    def call
      # take the timeline name
      # build the time line tree
      # loop through the routes using the sequence
      # for each route -> first run the check through the tree state
      # check it has everything it needs
      # for each route -> establish its section on the timeline tree
      # send a copy of the tree state -> to the route
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
      @timeline = CartridgeCore::Services::TreeBuilderService.build(timeline_key, **opts)
      sort_routes_by_sequence(@timeline.routes).map do |route|
        # remember that at this point route could also be [1,2]
        # after sorting through the routes, it could look like this [RouteClass1, [RouteClass2, RouteClass3]]
        if route.is_a?(CartridgeCore::Entities::Route)
          route.use_timeline!(@timeline).traverse!
        else
          reconciler = ::CartridgeCore::Entities::Reconciler.new
          # route here is a misnomer -> it will be a route group in this stead
          routes = route.map { |route| ->() { route.use_timeline!(@timeline).traverse! } }
          reconciler.concurrently_execute_with_reconciliation!(routes)
        end
      end

      @timeline.reload!
    end

    private

    attr_reader :timeline_key, :opts

    def concurrently_traverse_routes_with_reconciliation!(routes, timeline)
      reconciler = ::CartridgeCore::Entities::Reconciler.new
      routes = routes.map { |route| ->() { route.use_timeline!(timeline).traverse! } }
      reconciler.concurrently_execute_with_reconciliation!(routes)
    end

    def sort_routes_by_sequence(routes)
      return routes if @timeline.sequence.empty?

      @timeline.sequence.map do |entry_index|
        next routes[entry_index] unless entry_index.is_a?(Array)

        entry_index.map { |index| @timeline.routes[index] }
      end
    end
  end
end
