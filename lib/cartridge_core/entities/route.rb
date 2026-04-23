# frozen_string_literal: true

module CartridgeCore
  module Entities
    ROUTE_KEYS = %i[tree_state timeline stops reconcilers name index context checks balancers].freeze
    Route = Struct.new(*ROUTE_KEYS, keyword_init: true) do
      include CartridgeCore::Entities::Concerns::TreeState::CommitOperations
      include CartridgeCore::Services::EventBus::Concerns::Propagation
      include CartridgeCore::Errors::Concerns::DynamicErrorPropagation
      include CartridgeCore::Cache::Concerns::SelectivePersistence
      include CartridgeCore::Entities::Concerns::StateIntegrityEnforcement::Core

      persists!(*(ROUTE_KEYS - %i(context tree_state stops index)))

      def self.base_keys = ROUTE_KEYS

      # @param
      def use_timeline!(timeline)
        @timeline ||= timeline
        @tree_state ||= ::CartridgeCore::Entities::TreeState.new(current: timeline.tree_state.current.slice(name) || {})
        @parameters ||= Timeline::Tree::Parameters.wrap(timeline.context.parameters.dig(name))
        self
      end

      def traverse!
        ::CartridgeCore::Services::Routes::TraversalService.call(self)
      end

      alias_method :parent, :timelines
    end
  end
end
