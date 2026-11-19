# frozen_string_literal: true

module CartridgeCore
  module Entities
    ScheduledTimelineExecution = Struct.new(*%i(id timeline_id status serialized_context executes_at)) do
      include CartridgeCore::Cache::Concerns::SelectivePersistence
      index(:scheduled_timeline_executions)

      def filter_routes(routes)
        return routes unless serialized_context

        route_in_context = routes[serialized_context.dig(:route).to_sym]
        return routes unless route_in_context

        match = ->((_, v)) { v[:index] >= route_in_context[:index] }
        routes.entries.keep_if(&match).to_h
      end

      def filter_stops(stops)
        return stops unless serialized_context

        stop_in_context = stops[serialized_context.dig(:stop).to_sym]
        return stops unless stop_in_context

        match = ->((_, v)) { v[:index] > stop_in_context[:index] }
        stops.entries.keep_if(&match).to_h
      end
    end
  end
end
