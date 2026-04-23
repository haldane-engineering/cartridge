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
      tree_state
      definition_id
      head
      context
    )

    Tree = Struct.new(*TREE_KEYS, keyword_init: true) do
      include CartridgeCore::Services::EventBus::Concerns::Propagation
      include CartridgeCore::Entities::Concerns::TreeState::CommitOperations
      include ::CartridgeCore::Cache::Concerns::SelectivePersistence

      persists!(*TREE_KEYS - %i(reconcilers routes))

      def self.base_keys = BASE_KEYS

      def persist!(version, tree = nil)
        persistable_state = persistable_state[:trees].merge("#{version}": tree) if tree
        cache.snapshot!(id, persistable_state)
        reload!
      end

      def reload!
        _, n_state = cache.load!(id)
        ::CartridgeCore::Services::CacheActions::Load.apply(self, n_state)
        self
      end

      delegate :using_namespace, to: :context

      Context = Struct.new(*%i(parameters load_namespace), keyword_init: true) do
        def using_namespace(filenames) = filenames.map { |fname| "#{load_namespace || ""}/#{fname}" }
      end

      Parameters = OpenStruct.new do
        include ::CartridgeCore::Cache::Concerns::SelectivePersistence

        delegate :slice, to: :to_h
        delegate :dig, to: :to_h
        # example = get('source_population.available_games_retrieval.source_feed')
        def get(key) = dig(*key.split('.'))
        class << self; def wrap(value) = new(**value); end
      end
    end
  end
end
