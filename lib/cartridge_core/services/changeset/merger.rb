# frozen_string_literal: true

module CartridgeCore
  module Services
    module Changeset
      class Merger < Services::Base
        include CartridgeCore::Errors::Concerns::DynamicErrorPropagation

        def self.call(*args)
          new(*args).call
        end

        def initialize(tree_state, changeset)
          @changeset = changeset
          @tree_state = tree_state.current.dup
        end

        def call
          safely_execute do
            validate_changeset!
            changeset.each(&method(:merge_in_changeset_with_strategy))
            succeed(tree_state)
          end
        end

        private

        attr_reader :changeset, :entity, :tree_state

        def strategies
          @strategies ||= %i(add remove merge push concact split pop slice)
        end

        def merge_in_changeset_with_strategy(change_entry)
          @tree_state = case change_entry.strategy
          when :add
            # will need to update this to find the right key from state
            tree_state.merge("#{without_deleted_qualifier(change_entry.key.to_s)}": change_entry.value)
          when :merge
            tree_state.merge("#{change_entry.key}": tree_state[change_entry.key].merge(change_entry.value))
          when :push
            tree_state.merge("#{change_entry.key}": (tree_state[change_entry.key] || []).push(change_entry.value))
          when :concact
            tree_state.merge("#{change_entry.key}": (tree_state[change_entry.key] || []) + change_entry.value)
          # rollback actions
          when :remove
            # always soft delete
            tree_state.merge("#{change_entry.key}_deleted": tree_state.delete(change_entry.key))
          when :split
            tree_state.merge("#{change_entry.key}": tree_state[change_entry.key].except(*change_entry.value.keys))
          when :slice
            resultant_value = tree_state[change_entry.key].reject_if { |s_entry| change_entry.value.include?(s_entry) }
            tree_state.merge("#{change_entry.key}": resultant_value)
          when :pop
            resultant_value = tree_state[change_entry.key].reject_if { |s_entry| s_entry == change_entry.value }
            tree_state.merge("#{change_entry.key}": resultant_value)
          end
        ensure
          change_entry.applied = true
        end

        def without_deleted_qualifier(key) = key.gsup('_deleted', '')

        def validate_changeset!
          changset.each do |change_entry|
            halt!(:invalid_change_entry_error) if strategies.exclude?(change_entry.strategy)
            halt!(:invalid_change_entry_error) if change_entry.add? && !change_entry.value
            halt!(:invalid_change_entry_error) if change_entry.remove? && !(change_entry.value.is_a?(String) || change_entry.value.is_a?(Symbol))
          end
        end
      end
    end
  end
end
