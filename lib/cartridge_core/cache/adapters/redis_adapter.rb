# frozen_string_literal: true

# CartridgeCore::Cache::Adapters::RedisAdapter.new.search(q)
module CartridgeCore
  module Cache
    module Adapters
      class RedisAdapter
        include ::CartridgeCore::Errors::DynamicPropagation
        FLAT_OBJ_TYPES = [String, NilClass, Integer, Float].freeze

        # I3ndex doc looks like this
        # timelines: {}, events: {}, trees: {}, commits: {}, resolver_processes: {}, resolver_process_units
        def initialize(root = :cartridge)
          @statements = []
          @root_w_namespace = prefix_root(root) # could this include namespace? msaservices:cartridge
        end

        def load!(timeline_id, **load_opts)
          # load_opts example { only, except, cursor: { limit: 1000, from: 0}, association_name: { limit: 1000, from: 0}}
          # redis appends the nested keys (index_key plus the query key) to the root namespace in the resulting set.
          q_key = '$.timelines.id'
          timeline = get(timeline: { id: timeline_id }).dig(:timeline, q_key).first
          return unless timeline # not sure if to build a default object here and send as the response

          # firstly, remove the fields contained in the except params -> only applies to the first level (why? should apply at all levels: TODO)
          timeline = timeline.except(*load_opts.delete(:except))
          tl_keys = (timeline.keys & load_opts.delete(:only) if load_opts[:only].present?) || timeline.keys
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
          # args -> timeline_tree, time_line_tree
          # persist definitions, events, commits,
          extract_and_persist_root_indices!(*args)
          # persist_tree_head!(*args)
          persist_timeline!(*args)
        rescue
          # propagate the error here
          halt!(:redis_snapshpot_error)
        end

        def setup!
          return if indices_already_set_up?

          index_json = configuration[:full_key_set].index_with({}).to_json
          redis.call('JSON.SET', root_w_namespace, '$', index_json)
        rescue
          halt!(:redis_connection_error)
        end

        # @param [Hash] hash containing keys $indexname_id -> { timeline: { id: 2 }, commit_id: 2 }
        def get(**query)
          result_set = query.entries.map do |(k, v)| # v is the actual entity id
            index = k.to_s.split('_').first.pluralize
            # assumption here should be that the first key in the value entry will always be id
            # TODO - look into how you can combine AND requests here
            # sigh - eventually have to do some client side filtering here ^- Tired :((
            result = redis.call('JSON.GET', root_w_namespace, "$.#{index}.#{v.keys.first}", v.values.first)
            JSON.parse(result) if result
          end
          query.keys.zip(result_set).to_h
        end

        def root_get(key, klass)
          # Assumption here is that every
          index_resp = redis.call('JSON.GET', root_w_namespace, '$') || empty_index_response
          index_resp = JSON.parse(index_resp)
          index_resp.map(&->(obj) { klass.new(**obj) })
        end

        private

        attr_reader :statements, :root_w_namespace

        def extract_and_persist_root_indices!(*args)
          root_idx_keys.map { |key| [key, args] }.each(&method(:extract_values_and_persist!))
        end

        def indices_already_set_up?
          index_resp = redis.call('JSON.GET', root_w_namespace, '$') || empty_index_response
          index_resp.first && configuration[:full_key_set].map(&:to_s).sort == JSON.parse(index_resp).first.keys.sort
        end

        def extract_values_and_persist!(args)
          idx_key, _, tree_state = args.flatten
          tree_state[idx_key].each do |idx_entry|
            storable_key = "$.#{idx_key}.#{idx_entry.deep_symbolize_keys.dig(:id)}"
            redis.call('JSON.SET', root_w_namespace, storable_key, idx_entry.to_json)
          end
        end

        def persist_tree_head!(_, tree_state)
          tree = tree_state.dig(:trees, :"#{tree_state[:head]}")
          # ensure we're only storing refs -> this is the main timeline
          root_idx_keys.each do |key|
            tree[key] = tree_state[key].map(&:deep_symbolize_keys).pluck(:id) if tree.key?(key)
          end
          redis.call('JSON.SET', root_w_namespace, "$.trees.#{tree_state.dig(:head)}", tree.to_json)
        end

        def persist_timeline!(timeline_id, tree_state)
          nil_timeline = root_idx_keys.index_with([]).merge(head: nil).to_json
          timeline_from_cache = redis.call('JSON.GET', root_w_namespace, "$.timelines.#{timeline_id}")
          # -> timeline here will only
          empty_index_response = configuration[:empty_index_response]
          timeline = JSON.parse(timeline_from_cache != empty_index_response ? timeline_from_cache : nil_timeline)

          # trees commits events stop processes and units will all be an array of ids
          root_idx_keys.each { |key| timeline[key] = tree_state[key].pluck(:id) + timeline[key.to_s] }
          # trees
          timeline[:trees] = [tree_state.dig(:head), *(timeline[:trees] || [])]
          # Assign head -> most recently created tree version (different from the head of the tree  )
          timeline[:head] = tree_state.dig(:head)
          timeline[:definition_id] = tree_state.dig(:definition_id)
          redis.call('JSON.SET', root_w_namespace, "$.timelines.#{timeline_id}", timeline.to_json)
        end

        def nil_timeline_state = root_idx_keys.index_with([]).merge(head: nil)

        def populate_timeline_associations_using_cursor!(timeline, association, load_opts)
          offset, limit = load_opts[:cursor].merge(load_opts[association] || {}).values_at(*%i(offset limit))
          idx_to_records = ->(idx, assoc) do
            # apply constraints first
            idx = idx.slice(offset, limit + offset)
            association_query = idx.map { |id| "@.id == '#{id}'" }.join('||')
            results = redis.call('JSON.GET', root_with_namespace, "$.#{assoc}[?(#{association_query}})]")
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
            next record if eager_load_intersection.blank?

            eager_load_intersection.each do |eload_key|
              record[eload_key] = idx_to_records(record[eload_key], eload_key)
            end
          end
          timeline[association] = fully_populated_association_entries
          timeline
        end

        def prefix_root(root) = "#{root ? "#{root}:" : ""}#{configuration[:root_namespace]}"

        def configuration
          @configuration ||= {
            root_namespace:        :catridgecore,
            default_cursor_limit:  1000,
            default_cursor_offset: 0,
            full_key_set:          %i(timelines trees) + root_idx_keys,
            empty_index_response:  '[]',
          }
        end

        def redis
          @redis ||= Redis.new
        end

        def root_idx_keys
          @root_idx_keys ||= %i(
            definitions commits events stop_processes stop_process_units scheduled_executions
          )
        end

        def base_load_opts
          @base_load_opts = {
            only:            [],
            except:          [],
            eager_load_keys: root_idx_keys.unshift(:tree_states),
            cursor:          {
              limit:  configuration[:default_cursor_limit],
              offset: configuration[:default_cursor_offset],
            },
          }
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
      end
    end
  end
end
