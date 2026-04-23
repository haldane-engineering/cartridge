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
    include CartridgeCore::Errors::Concerns::DynamicErrorPropagation

    def initialize(adapter: :redis)
      build_schema!
      @adapter = adapters[adapter].new(:catridge)
      adapter.setup!
    end

    # args here are timeline_id and the query opts (pagination and inclusionary attributes)
    def load!(*args)
      timeline = adapter.load!(*args) || setup_initial_timeline!
      # return the head tree_state and the timeline in response
      current_tree_state_for_timeline = timeline.dig(:trees, timeline[:head])
      [current_tree_state_for_timeline, timeline]
    end

    def timeline_state_for(definition_hash)
      @sample_definition = ::CartridgeCore::Entities::Definition.new(id: definition_hash)
      timeline = adapter.get({ timeline: { definition_id: definition_hash } }) || setup_initial_timeline!
      load!(timeline.dig(:id))
    end

    # args here are timeline_id and the timeline persistable_state
    def snapshot!(*args)
      adapter.snapshot!(*args)
      load!(args.first) # timeline_id is the first args
    end

    private

    attr_reader :adapter

    def setup_initial_timeline!
      snapshot!(initial_tree_state[:id], initial_tree_state)
      load!(initial_tree_state[:id])
    end

    def initial_tree_state
      @initial_tree_state ||= begin
        r_timestamp = Time.parse('3rd Feb 1996 10:30pm').to_i # 823383000, My Birthday hahahahaha
        @sample_definition ||= factory(::CartridgeCore::Entities::Definition).build
        sample_route = factory(::CartridgeCore::Entities::Route).build
        real_commit = factory(::CartridgeCore::Entities::TreeState::Commit).build
        initial_commit = ::CartridgeCore::Entities::RepositoryCommit.new(
          commit: real_commit,
          id: real_commit.id,
          applied: true,
          applied_at: r_timestamp,
        )

        {
          id:            SecureRandom.hex(8),
          head:          r_timestamp,
          definition_id: sample_definition.id,
          definitions:   [{ raw: @sample_definition.to_json, id: @sample_definition.id, timestamp: r_timestamp }],
          trees:         {
            "#{r_timestamp}": {
              current:       {},
              commits:       [initial_commit.persistable_state],
              head:          initial_commit.id,
              parameters:    sample_parameter_set.persistable_state,
              definition_id: @sample_definition.id,
              routes:        {
                # see reference for structure -> should contain stops
                route_1: sample_route.persistable_state,
              },
            },
          },
          commits:       [initial_commit.persistable_state],
          events:        [sample_event.persistable_state],
        }
      end
    end

    def adapters(adapter_key)
      @adapters ||= {
        redis: ::CatridgeCore::Cache::Adapters::RedisAdapter,
      }
    end

    def factory(klass) = Factory.build(klass)

    class Factory
      def self.build(*args) = new.build(*args)

      def build(klass)
        factory_key = klass.name.split('::').last.downcase
        yaml_content = YAML.safe_load_file(Rails.root.join('lib/cartridge_core/cache/factory/samples.yml'))
        klass.new(**yaml_content[factory_key])
      end
    end
  end
end
