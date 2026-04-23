# frozen_string_literal: true

require 'digest'

module CartridgeCore
  module Services
    module Merge
      class Engine < BaseService
        STRATEGIES = { add: :add, remove: :remove }
        class InvalidChangeEntryError < StandardError; end

        def initialize(tree, changeset, origin:)
          @tree = tree
          @changeset = changeset
          @origin = origin
        end

        def merge
          # takes a collection of changesets
          # stores the origin -> as a key in the tree state
          # changeset => [{ strategy: :add, key: _key_ value: }, { strategy: :remove, key: key }]
          # loops through the changeset and applies each of the changes to it's copy of the state
          validate_changeset!
          version_state_using_origin!
          # apply the changes
          changeset.each(&method(:merge_in_changeset_with_strategy))
          tree.tree_state
        end

        private

        attr_reader :tree, :changeset, :origin

        def merge_in_changeset_with_strategy(changeset)
          tree_state = tree.tree_state.dup
          tree.tree_state = case changeset.strategy
          when :add
            # remember to delegate merge to internal #merge method
            tree_state.merge("#{changeset.key}": changeset.value)
          when :remove
            tree_state.except(changeset.key)
          end
        end

        def version_state_using_origin!
          # register_version! should create a separate entry in the store
          # for this particular version, the goal is to make this more
          # accessible during rollback
          version_id, commit = generate_version_identifier
          tree.register_version!(
            # Identifier should be a concat of the process_name + the current timestamp + timeline_id
            # also include the origin.type
            version: version_id,
            changeset: changesets.to_json,
            pre_application_state: tree.tree_state,
            commit: commit,
          )
        end

        def generate_version_identifier
          # Ideally this should be a hash of this e.g '1757252001_timeline_12345_route_pr
          version_id = "#{Time.zone.now.to_i}_timeline_#{timeline.id}_#{origin.type}_#{origin.process_name}"
          commit = Digest::SHA256.hexdigest(version_id)
          [version_id, commit]
        end

        def after_validating_changes!(changeset)
          # check that all the changes contained have a valid strategy
          # Ideally these validations should be run in the input
          changeset.each do |change_entry|
            if STRATEGIES.exclude?(change_entry.strategy) || (change_entry.strategy.add? && !!!change_entry.value)
              raise InvalidChangeEntryError
            end
          end
        end
      end
    end
  end
end
