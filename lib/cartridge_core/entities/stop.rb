# frozen_string_literal: true

module CartridgeCore
  module Entities
    STOP_KEYS = %i(
      applied
      changeset
      name
      route
      checks
      balancers
      index
      parameters
      spawns_processes
      schedulable
      schedules_execution
      class_name
      context
    )
    Stop = Struct.new(*STOP_KEYS, keyword_init: true) do
      include CartridgeCore::Services::EventBus::Concerns::Propagation
      include CartridgeCore::Cache::Concerns::SelectivePersistence
      include CartridgeCore::Entities::Concerns::StateIntegrityEnforcement::Core
      include CartridgeCore::Entities::Stops::Cartridges::Enablement

      persists!(*%i(applied name changeset))

      def self.apply!(*args)
        new(*args).apply!
      end

      def with_context(context)
        self.context ||= context
        self
      end

      def assign_changeset(changeset)
        self.changeset = changeset
        self
      end

      def apply!
        # Stops are the lowest levels of execution, they essentially take in the tree state -> stop.route.tree_state.current
        # execute their internal logic and generate a changeset -> which is a collection of change entries
        # after which the balancer is triggered -> this performs an initial application of the change entries
        # to the routes current state and then verifies that the required keys are present, not null and in the future
        # match certain values -> if yes the list of change entries are then added to the route's list of change entries
        # along with an index (or maybe that's already predetermined || can overriden by the sequence attribute)
        ::CartridgeCore::Services::Stops::Applicator.apply!(self)
        self
      end
    end
  end
end
