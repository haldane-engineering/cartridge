# frozen_string_literal: true

# CartridgeCore::Cache::Adapters::RedisAdapter.new.search(q)
module CartridgeCore
  module Cache
    module Adapters
      class RedisAdapter
        include ::CartridgeCore::Errors::DynamicPropagation
        FLAT_OBJ_TYPES = [String, NilClass, Integer, Float].freeze

        # I3ndex doc looks like this
        # timelines: {}, events: {}, trees: {}, commits: {}
        def initialize(root)
          @statements = []
          @root_w_namespace = prefix_root(root) # could this include namespace? msaservices:cartridge
        end

        def load(timeline_id, **load_opts)
          # load_opts example { only, except, cursor: { limit: 1000, from: 0}, association_name: { limit: 1000, from: 0}}
          timeline = get(timeline: { id: timeline_id }).dig(:timeline)
          return unless timeline # not sure if to build a default object here and send as the response

          # firstly, remove the fields contained in the except params -> only applies to the first level (why? should apply at all levels: TODO)
          timeline = timeline.except(*load_opts.delete(:except))
          tl_keys = timeline.keys & load_opts.delete(:only) if load_opts[:only].present?
          timeline = tl_keys.index_with { |tl_key| timeline[tl_key] }

          load_opts = base_load_opts.merge(load_opts)
          # remember that the root timeline only contains references
          # load all the root entries so for example -> { id: 1234, head: 1243, commits: [2323, 23343], trees }
          #  becomes { ...rest_of_hash, commits: [{ id: 2323, ...rest_of_commit_body }] }
          load_opts[:eager_load_keys].each do |a_key|
            populate_timeline_associations_using_cursor!(timeline, a_key, load_opts)
          end
          timeline
        end

        def snapshot!(*args)
          # persist definitions, events, commits
          base_idx_keys.map { |key| [key, args] }.each(&method(:extract_values_and_persist!))
          base_idx_keys.each do |key|
            send(:"persist_#{key}_from_state!", args.last)
          end
          # persist tree state
          persist_tree_state!(*args)
          persist_timeline!(*args)
        rescue
          # propagate the error here
          halt!
        end

        def setup!
          configuration[:full_key_set].each do |index_key|
            next if redis.execute_command('JSON.GET', root_w_namespace, "$.#{index_key}")

            redis.execute_command('JSON.SET', root_w_namespace, "$.#{index_key}", {}.to_json)
          end
        rescue
          halt!(:redis_connection_error)
        end

        # @param [Hash] hash containing keys $indexname_id -> { timeline: { id: 2 }, commit_id: 2 }
        def get(**query)
          result_set = query.entries.map do |(k, v)| # v is the actual entity id
            index = k.split('_').first.pluralize
            # assumption here should be that the first key in the value entry will always be id
            # TODO - look into how you can combine AND requests here
            result = redis.execute_command('JSON.GET', root_w_namespace, "$.#{index}.#{v.keys.first}", v.keys.last)
            JSON.parse(result) if result
          end
          query.keys.zip(result_set).to_h
        end

        private

        attr_reader :statements

        def extract_values_and_persist!(args)
          idx_key, _, tree_state = args.flatten
          tree_state[idx_key].each do |idx_entry|
            storable_key = "$.#{idx_key}.#{idx_entry.id}"
            redis.execute_command('JSON.SET', root_w_namespace, storable_key, idx_entry.to_json)
          end
        end

        def persist_tree_state!(_, tree_state)
          # ensure we're only storing refs
          base_idx_keys.each do |key|
            tree_state[key] = tree_state[key].map(&:id)
          end
          redis.execute_command('JSON.SET', root_w_namespace, "$.trees.#{tree_state.id}", tree_state.to_json)
        end

        def persist_timeline!(timeline_id, tree_state)
          nil_timeline_state = base_idx_keys.index_with([]).merge(head: nil)
          timeline_from_cache = redis.execute_command('JSON.GET', root_w_namespace, "$.timelines.#{timeline_id}")
          timeline = JSON.parse(timeline_from_cache || nil_timeline_state.to_json)

          base_idx_keys.each { |key| timeline[key] = tree_state[key].map(&:id) + timeline[key] }
          # trees
          timeline[:trees] = [tree_state.id, *(timeline[:trees] || [])]
          # Assign head -> most recently created tree version (different from the head of the tree  )
          timeline[:head] = tree_state.id
          timeline[:definition_id] = tree_state.definition_id
          redis.execute_command('JSON.SET', root_w_namespace, "$.timelines.#{timeline_id}", timeline.to_json)
        end

        def nil_timeline_state = base_idx_keys.index_with([]).merge(head: nil)

        def populate_timeline_associations_using_cursor!(timeline, association, load_opts)
          offset, limit = load_opts[:cursor].merge(load_opts[association] || {}).values_at(*%i(offset limit))
          idx_to_records = ->(idx, assoc) do
            # apply constraints first
            idx = idx.slice(offset, limit + offset)
            association_query = idx.map { |id| "@.id == '#{id}'" }.join('||')
            results = redis.execute_command('JSON.GET', root_with_namespace, "$.#{assoc}[?(#{association_query}})]")
            JSON.parse(results) if results
          end

          # this naively assumes that associations can only be two tiers deep i.e { timeline: { trees: [{ commits: [commit_id] }], commits: [commit] } }
          # for now that is the case but in the future I imagine we have to adjust this to recursively populate associations n level
          # deep
          fully_populated_association_entries = (idx_to_records.call(
            timeline[association],
            association,
          ) || []).map do |record|
            eager_load_intersection = record.keys.map(&:to_sym) & load_opts[:eager_load_keys] == []
            next record unless eager_load_intersection.present?

            eager_load_intersection.each do |eload_key|
              record[eload_key] = idx_to_records(record[eload_key], eload_key)
            end
          end
          timeline[association] = fully_populated_association_entries
          timeline
        end

        def prefix_root(key) = "#{root ? "#{root}:" : ""}#{configuration[:root_namespace]}"

        def configuration
          @configuration ||= {
            root_namespace:        :catridgecore,
            default_cursor_limit:  1000,
            default_cursor_offset: 0,
            full_key_set:          %i(timelines trees) + base_idx_keys,
          }
        end

        def redis
          @redis ||= Redis.new
        end

        def base_idx_keys
          @base_idx_keys ||= %i(definitions commits events)
        end

        ######## REDUNDANT METHODS ############
        def denormalize(query, sets: false)
          flatten_hash(query)
        end

        def flatten_list(list, parents = [])
          list.each.with_index do |l_entry, index|
            new_parents = [*parents, "[#{index}]"]

            next insert_statement!(l_entry, new_parents) if FLAT_OBJ_TYPES.include?(l_entry.class)
            next flatten_list(l_entry, new_parents) if l_entry.is_a?(Array)
            next flatten_hash(l_entry, new_parents) if l_entry.is_a?(Hash)
          end
        end

        def flatten_hash(hash, parents = [])
          hash.entries.each.with_index do |(k, l_entry), _index|
            new_parents = [*parents, k]
            next insert_statement!(l_entry, new_parents) if FLAT_OBJ_TYPES.include?(l_entry.class)

            next flatten_list(l_entry, new_parents) if l_entry.is_a?(Array)
            next flatten_hash(l_entry, new_parents) if l_entry.is_a?(Hash)
          end
        end

        def insert_statement!(value, parent_keys)
          statements.push([parent_keys.join('.'), value])
        end

        def flatten_with_parents(parents)
        end

        def base_load_opts
          @base_load_opts = {
            only:            [],
            except:          [],
            eager_load_keys: base_idx_keys.unshift(:trees),
            cursor:          {
              limit:  configuration[:default_cursor_limit],
              offset: configuration { :default_cursor_offset },
            },
          }
        end
      end
    end
  end
end
