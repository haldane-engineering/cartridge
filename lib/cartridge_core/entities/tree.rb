# frozen_string_literal: true

require 'ostruct'

module CartridgeCore
  module Entities
    BASE_KEYS = %i(name description sequence)
    TREE_KEYS = %i(
      name
      routes
      description
      sequence
      reconcilers
      definitions
      events
      commits
      trees
      id
      key
      tree_state
      definition_id
      scheduled_execution_memberships
      head
      execution_state
      context
      scheduled_timeline_executions
      stop_processes
      stop_process_units
      version
    )

    Tree = Struct.new(*TREE_KEYS, keyword_init: true) do
      include CartridgeCore::Services::EventBus::Concerns::Propagation
      include CartridgeCore::Entities::Concerns::TreeState::CommitOperations
      include ::CartridgeCore::Cache::Concerns::SelectivePersistence

      persists!(*TREE_KEYS - %i(reconcilers routes))

      def self.base_keys = BASE_KEYS

      # @param [String | Integer] version the version number for this new tree
      # tree
      def persist!(new_tree_state: nil)
        # persistable_state[:trees] is a list of tree_states, when fetching from the cache
        # during the association population step -> trees returns as an array but during tree snapshotting
        # it expects a hash -> this is a design flaw I need to address.
        transform_tree_state = ->(tree_state) { head?(tree_state) ? tree_state.assign_attributes!(new_tree_state).to_h : tree_state } 
        persistable_state[:trees] = persistable_state[:trees].map(&transform_tree_state)
        cache.snapshot!(id, persistable_state)
        reload!
      end

      def reload!
        _, n_state = cache.load!(id)
        ::CartridgeCore::Services::CacheAtreections::Load.apply!(self, n_state)
        self
      end

      delegate :using_namespace, to: :context

      private

      def head?(tree_state)
        tree_state.id == head
      end

      def ass
    end
  end
end
