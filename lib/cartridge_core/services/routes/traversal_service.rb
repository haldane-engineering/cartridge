# frozen_string_literal: true

module CartridgeCore
  module Services
    module Routes
      class TraversalService < BaseService
        include ::CartridgeCore::Errors::DynamicPropagation

        def self.call(*args) = new(*args).call

        def initialize(route, **traversal_opts)
          @route = route
          @context = Context.new(default_traversal_opts.merge(traversal_opts))
        end

        def call
          route.timeline.register_activity!(route, :route_application_start)
          # assume here that sequence looks like this -> ["source_population", ["available_games_retrieval", 'game_logs_retrieval]]
          preselect_stops_in_context(populate_stops_with_sequence(route.stops)).each do |stop|
            next process_stops_with_reconciler(stop) if stop.is_a?(Array)

            commit_stop_changeset_to_tree_state!(stop.apply!)
          end
        ensure
          route.timeline.register_activity!(route, :route_application_end)
        end

        private

        attr_reader :route, :context

        def commit_stop_changeset_to_tree_state!(stop)
          halt!(:unsuccesful_stop_execution_error, stop.context.errors.map(&:message)) unless stop.context.success?
          merge_ctx = ::CartridgeCore::Services::Changeset::Merger.call(stop, stop.changeset)
          halt!(:unsuccessful_merge_error, merge_ctx.errors) unless merge_ctx.success?
          route.commit!(stop.changeset, merge_ctx.payload)
        end

        def populate_stops_with_sequence(stops)
          stops_sequence = route.sequence.presence || route.stops.map.with_index(&->(_, index) { index })
          stops_sequence.map do |s_index|
            next stop_for(s_index) unless s_index.is_a?(Array)

            s_index.map { |stop_index| [stop_index, stop_for(stop_index)] }
          end
        end

        def stop_for(index) = route.stops.find(&->(stop) { stop.index == index })

        # rubocop:disable Style/NestedTernaryOperator
        # @param [String] stops - a list of stops to executed. Useful for replays
        def preselect_stops_in_context(stops)
          return stops if context.stops.empty?

          camelized_stops = context.stops.map(&:camelize)
          match = ->(stop) { camelized_stops.any? { |st_name| stop.name.include?(st_name) } }
          match_included = ->(stop) { stop.is_a?(Array) ? stop.filter(&match) : (match.call(stop) ? stop : nil) }
          stops.map(&match_included).flatten(1).compact
        end
        # rubocop:enable Style/NestedTernaryOperator

        def default_traversal_opts
          @default_traversal_opts ||= { stops: [], parameters: {} }
        end

        def process_stops_with_reconciler(stop_groups)
          # Each route can contain a list of reconcilers, a typical reconciler entry in the list
          # of reconcilers should look like this { reconcilers: available_games_reconciler: { sequence: [1,2], name: :available_games_reconciler }}
          reconciler = ::CartridgeCore::Entities::Reconciler.new
          stops = stop_groups.map(&:last).map { |stop| -> () { stop.apply! } }
          reconciler.concurrently_execute_with_reconciliation!(stops).each(&method(:commit_stop_changeset_to_tree_state!))
        end

        Context = Struct.new(*%i(stops parameters), keyword_init: true)
      end
    end
  end
end
