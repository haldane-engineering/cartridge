# frozen_string_literal: true

# structure of the entire cache looks like this
# {
# in the future, we should store configurations, authors: a
# timelines: [{
# timeline_id: _timeline_id,
# definitions: {[ raw: stringified_hash_of_schema, id: generated_id, timestamp: Time.zone.now ]}
# db: {
#     head: _latest_commit_id,
#     trees: {
#      timestamp(123467908080): { #created_at, Time.zone.now.to_i
#         id: timestamp
#         current: { tl_tree_state_key_1: tl_tree_state_value_1, tl_tree_state_key_2: tl_tree_state_value_2 },
#         commits: [#RCommit<{ id: dfdf, commit: { id: _commit_id, changeset: [*changeset_list], initial_state: {}, final_state: {} }}>],
#         head: commit_id,
# .        parameters: {},
#         definitions: [{definition_id}],
#         routes: {
#             route_1: {
#                  tree_state: { **only_current_tree_state, commits: [{ #RCommit<{ id: dfdf, commit: { id: _commit_id, changeset: [*changeset_list], initial_state: {}, final_state: {} }}>}] },
# .                 when loading, set the main tree state key to the tl.tree_state and initial_state as the one loaded from cache,
#                  stops: {
#                      stop_1: { applied: true, changeset: [{ }], context: { parameters: {} }, name: stop_1 },
#                      stop_2: { applied: true, changeset: [{}] }} #end stops
#                     } #end route 1
# }  # end routes
#               }, # end tree_entry_1
#          },  # end trees
#      events: [{  title: event_title, metadata: {  using_commit_id: :xC12232345},
#             actor: ro_asfd.st_st_name_id, executor: ro_asf, id: 13wre }],
#
#   }
# }
# }]
module CartridgeCore
  class ICache
    include CartridgeCore::Errors::DynamicPropagation

    def initialize(adapter_type: :redis)
      @adapter = adapters[adapter_type].new(:cartridge)
      adapter.setup!
    end

    # args here are timeline_id and the query opts (pagination and inclusionary attributes)
    def load!(*args)
      timeline = adapter.load!(*args)
      # return the head tree_state and the timeline in response
      current_tree_state_for_timeline = timeline.dig(:trees, timeline[:head])
      [current_tree_state_for_timeline, timeline]
    end

    # @param [String] timeline_id well, the id of the timeline
    # @param [Hash | nil] the initial definition json -> we use this to set up a new timeline instance
    def timeline_state_for(definition_id, initial_definition:)
      @sample_definition = ::CartridgeCore::Entities::Definition.new(id: definition_id)
      timeline_from_cache = adapter.get(timeline: { definition_id: definition_id }).dig(:timeline)
      timeline = timeline_from_cache.presence || setup_initial_timeline!(definition_id, initial_definition.to_json)
      load!(timeline.dig(:id))
    end

    # args here are timeline_id and the timeline persistable_state
    def snapshot!(*args)
      adapter.snapshot!(*args)
    end

    private

    attr_reader :adapter

    def setup_initial_timeline!(definition_id, definition_json)
      timeline_tree = initial_timeline_tree(definition_id, definition_json)
      snapshot!(definition_id, timeline_tree)
      adapter.load!(timeline_tree[:id])
    end

    # @param [String] definition_hash the id of the tineline definition
    # @param [String] the json string of the definition
    # @preturn [Hash] an empty hash with all entries empty
    def initial_timeline_tree(definition_hash, definition_json)
      {
        id:                            SecureRandom.hex(8),
        head:                          Factory.initial_timestamp,
        definition_id:                 definition_hash,
        definitions:                   [{
          raw:       definition_json,
          id:        definition_hash,
          timestamp: Factory.initial_timestamp,
        }],
        trees:                         {
          "#{Factory.initial_timestamp}": {
            current:        {},
            commits:        [],
            stop_processes: [],
            head:           Factory.initial_commit.id,
            parameters:     [],
            definition_id:  definition_hash,
            routes:         {},
            id:             Factory.initial_timestamp,
          },
        },
        commits:                       [],
        events:                        [],
        stop_processes:                [],
        stop_process_units:            [],
        scheduled_timeline_executions: [],
      }
    end

    def central_initial_timestamp = Time.parse('3rd Feb 1996 10:30pm').to_i

    def adapters
      {
        redis: ::CartridgeCore::Cache::Adapters::RedisAdapter,
      }
    end

    def factory(klass) = Factory.new(klass)

    class Factory
      class << self
        def build(*args) = new(*args).build

        def initial_commit
          state_commit = build(::CartridgeCore::Entities::StopProcess)
          ::CartridgeCore::Entities::TreeStates::RepositoryCommit.new(
            commit: state_commit,
            id: state_commit.id,
            applied: true,
            applied_at: Factory.initial_timestamp,
          )
        end

        def initial_timestamp
          Time.parse('3rd Feb 1996 10:30pm').to_i # Thats my birthday :))
        end

        def sample_timeline
          r_timestamp = Time.parse('3rd Feb 1996 10:30pm').to_i # 823383000, My Birthday hahahahaha
          @sample_definition ||= build(::CartridgeCore::Entities::Definition)
          sample_route = build(::CartridgeCore::Entities::Route).build
          real_commit = build(::CartridgeCore::Entities::TreeStates::Commit)
          sample_parameter_set = build(::CartridgeCore::Entities::Trees::Parameter)
          sample_event = ::CartridgeCore::Entities::EventBus::Event.new(title: :initialized_state, id: r_timestamp)
          sample_stop_process = build(::CartridgeCore::Entities::StopProcess)
          sample_stop_process_unit = build(::CartridgeCore::Entities::Stoprocess::Unit)
          sample_scheduled_execution = build(::CartridgeCore::Entities::ScheduledTimelineExecution)
          initial_commit = ::CartridgeCore::Entities::TreeStates::RepositoryCommit.new(
            commit: real_commit,
            id: real_commit.id,
            applied: true,
            applied_at: r_timestamp,
          )
          {
            id:                            SecureRandom.hex(8),
            head:                          r_timestamp,
            definition_id:                 @sample_definition.id,
            definitions:                   [{
              raw:       @sample_definition.to_json,
              id:        @sample_definition.id,
              timestamp: r_timestamp,
            }],
            trees:                         {
              "#{r_timestamp}": {
                current:        {},
                commits:        [initial_commit.persistable_state],
                stop_processes: [sample_stop_process.persistable_state],
                head:           initial_commit.id,
                parameters:     sample_parameter_set.persistable_state,
                definition_id:  @sample_definition.id,
                routes:         {
                  # see reference for structure -> should contain stops
                  route_1: sample_route.persistable_state,
                },
              },
            },
            commits:                       [initial_commit.persistable_state],
            events:                        [sample_event.persistable_state],
            stop_processes:                [sample_stop_process.persistable_state],
            stop_process_units:            [sample_stop_process_unit.persistable_state],
            scheduled_timeline_executions: [sample_scheduled_execution],
          }
        end
      end

      def initialize(klass)
        @klass = klass
      end

      def build
        factory_key = @klass.name.split('::').last.underscore.to_sym
        yaml_content = YAML.safe_load_file(Rails.root.join('lib/cartridge_core/cache/factory/samples.yml')).deep_symbolize_keys
        @klass.new(**yaml_content[factory_key])
      rescue
        require 'pry'
        binding.pry
      end
    end
  end
end
