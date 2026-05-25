# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Timelines
      ScheduledExecution = Struct.new(*%i(id timeline_id status serialized_context executes_at)) do
        include CartridgeCore::Cache::Concerns::SelectivePersistence

        def filter_routes(routes)
          return routes unless serialized_context

          route_in_context = routes[serialized_context.dig(:route, :name)]
          select = ->((_, v)) { v[:index] >= route_in_context[:index] }
          routes.entries.keep_if(&select).to_h
        end

        def filter_stops(stops)
          return stops unless serialized_context

          stop_in_context = stops[serialized_context.dig(:stop, :name)]
          select = ->((_, v)) { v[:index] >= stop_in_context[:index] }
          stops.entries.keep_if(&select).to_h
        end
      end
    end
  end
end
