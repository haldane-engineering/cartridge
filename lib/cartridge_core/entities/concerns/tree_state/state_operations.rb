# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Concerns
      module TreeState
        module StateOperations
          # @param [String] key should be one of 'route_name.stop_name.value' or '$ro_routename.st_stopname.value.commit_id'
          # if the key begins with $then you can assume the
          # @return [Any]
          def get(key)
            return current.dig(key) if flat_key?(key)

            # ex: 'available_games_retrieval.game_ids' -> '$st_available_games_retrieval.game_ids.xC03434j454"
            key_parts = key.split('.')
            leaf_field = key_parts.pop # 'game_ids' from example
            accessors = key_parts.reverse.map.with_index do |entry, index|
              "#{key_index_prefixes[index.to_s]}_#{entry}"
            end
            # looks something like this [["st_available_games_retrieval", "ro_source_population"], ""]
            full_key_with_commit = entry_for(['$', *accessors.reverse, leaf_field].join('.'))
            if full_key_with_commit
              k_value = current.dig(entry_for(full_key_with_commit).first)
              JSON.parse(k_value) if k_value
            end
          end

          # @param [CartridgeCore::Entities::Commit] commit the commit to be applied
          # @return nil
          def apply_commit!(commit)
            # TODO: might need to perform some checks here before applying
            self.current = current.except(*commit.original_state.keys).merge(commit.final_state)
            commit_params = { id: commit.id, entity: commit, applied: true, timestamp: Time.zone.now.to_i }
            repository_commit = TreeState::RepositoryCommit.new(**commit_params)
            # Ensure to remove the contained commits if they are present and it's an undo action.
            # This is pretty much the only part of this application I'm quite uncomfortable with
            # the complete disappearance of work done -> the data is absolutely reversible, but the loss of the
            # commit is concerning to me. Anyway nothing is ever truly lost on cartridge, I'll find a way to store
            # the deleted commits in another list -> TODO
            slice_off_contained_commits!(commit) if commit.undo?
            commits.unshift(repository_commit)
            self.head = commits.first.id
          end

          def find_commit(commit_id, with_index: false)
            commit = commits.find { |commit| commit.id == commit_id }.entity
            with_index ? [commit, find_commit_index(commit_id)] : commit
          end

          def preceeding_commit_for(commit_id, with_index: false)
            c_index = find_commit_index(commit_id) - 1
            commit = commits[c_index].entity
            with_index ? [commit, c_index] : commit
          end

          private

          def flat_key?(key) = key.starts_with?('$')

          def find_commit_index(commit_id) = commits.index_of { |commit| commit.id == commit_id }

          def key_index_prefixes = @key_index_prefixes ||= { '0' => 'st', '1' => 'ro' }

          def slice_off_contained_commits!(commit)
            _, index = find_commit(commit.id, with_index: true)
            # including the original commit, will be unshift into later.
            commits.slice!(0, index)
          end

          def entry_for(target_key)
            current_key = current.keys.find do |key|
              key.to_s.include?(target_key.to_s)
            end
            [current_key, current[current_key]]
          end
        end
      end
    end
  end
end
