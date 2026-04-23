# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Concerns
      module StateIntegrityEnforcement
        include ::CartridgeCore::Errors::DynamicPropagation

        def validate_entity_state_with_changeset!(tree_state)
          halt!(:missing_state_key_error) if required.any? { |c_entry| !tree_state.dig(c_entry) }
        end

        module Core
          def apply_checks!(tree_state) = run_guard_classes!(tree_state, :check)
          def apply_balancers!(tree_state) = run_guard_classes!(tree_state, :balancer)

          private

          def run_guard_classes!(*args)
            tree_state, guard_type = args
            send(:"#{guard_type.pluralize}").each do |guard|
              parent.register_activity!(guard, :"#{guard_type}_application_start")
              guard.validate_entity_state_with_changeset!(tree_state)
              parent.register_activity!(guard, :"#{guard_type}_application_end")
            end
          end
        end
      end
    end
  end
end
