# frozen_string_literal: true

module CartridgeCore
  module Entities
    ROUTE_KEYS = %i[
      tree_state
      timeline
      stops
      reconcilers
      name
      index
      context
      checks
      balancers
      parameters
      sequence
    ].freeze
    Route = Struct.new(*ROUTE_KEYS, keyword_init: true) do
      include CartridgeCore::Entities::Concerns::TreeState::CommitOperations
      include CartridgeCore::Services::EventBus::Concerns::Propagation
      include CartridgeCore::Errors::DynamicPropagation
      include CartridgeCore::Cache::Concerns::SelectivePersistence
      include CartridgeCore::Entities::Concerns::StateIntegrityEnforcement::Core

      persists!(*(ROUTE_KEYS - %i(context tree_state stops index definitions)))

      def self.base_keys = ROUTE_KEYS

      # @param
      def use_timeline!(timeline)
        self.timeline ||= timeline
        self.tree_state ||= ::CartridgeCore::Entities::TreeState.new(current: timeline.tree_state.current.slice(name) || {})
        self.parameters ||= ::CartridgeCore::Entities::Trees::Parameters.new(**timeline.context.parameters.fetch(
          name,
          {},
        ))
        self
      end

      def traverse!
        ::CartridgeCore::Services::Routes::TraversalService.call(self)
      end

      def preceeding = timeline.routes[index - 1]
      def next = timeline.routes[index + 1]

      alias_method :parent, :timeline
    end
  end
end
