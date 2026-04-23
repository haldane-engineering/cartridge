# frozen_string_literal: true

module CartridgeCore
  module Entities
    module TreeState
      CommitState = Struct.new(*%i(original final), keyword_init: true)
      RepositoryCommit = Struct.new(%i(id commit applied applied_at), keyword_init: true) do
      end

      Commit = Struct.new(*%i(state rollback_state contains changeset), keyword_init: true) do
        include ::CartridgeCore::Cache::Concerns::SelectivePersistence
        persists!(*%i(state rollback_state contains changeset))

        def initialize(**kwargs)
          super(**kwargs)
          @state = CommitState.new
        end

        def assign_original_state!(state)
          state.original = state
        end

        def assign_final_state!(state)
          state.final = state
        end

        def assign_attributes!(**attributes)
          attributes.entries.each do |(key, value)|
            send(:"#{key}=", value)
          end
          self
        end

        def undo?
          rollback_state == :undo
        end
      end
    end
  end
end
