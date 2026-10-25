# frozen_string_literal: true

module CartridgeCore
  module Entities
    module TreeStates
      CommitState = Struct.new(*%i(original final), keyword_init: true)

      Commit = Struct.new(*%i(state rollback_state contains changeset id stop), keyword_init: true) do
        include ::CartridgeCore::Cache::Concerns::SelectivePersistence
        index(:commits)
        persists!(*%i(state rollback_state contains changeset id))

        def initialize(**kwargs)
          super(**kwargs)
          self.state = CommitState.new
        end

        def assign_original_state!(state)
          self.state.original = state
          self
        end

        def assign_final_state!(state)
          self.state.final = state
          self
        end

        def assign_attributes!(**attributes)
          attributes.entries.each do |(key, value)|
            send(:"#{key}=", value)
          end
          self
        end

        def original_state = state.original
        def final_state = state.final

        def undo?
          rollback_state == :undo
        end
      end
    end
  end
end
