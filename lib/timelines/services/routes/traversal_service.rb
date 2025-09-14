# frozen_string_literal: true

module Timelines
  module Services
    module Routes
      class TraversalService < BaseService
        def self.call(*args)
          new(*args).call
        end

        def initialize(route)
          # the idea here is to get all the stops
          # loop through each one, run the checks and balancers
          @route = route
          @context = {}
        end

        def call
          # assume here that sequence looks like this -> ["source_population", ["available_games_retrieval", 'game_logs_retrieval]]
          populate_stops_with_sequence(route.stops).each do |stop|
            next process_stops_with_reconciler(stop) if stop.is_a?(Array)

            route.register_activity!(stop, :stop_application_start)
            # routes should also provide some shared context
            # stops should be able to get input from the already
            # run stops -
            #
            # populate check classes here should initialize each stop with the
            # route and then call apply -> apply raises an error if anything happend
            populate_check_classes(stop.checks).each(&:apply!)
            changeset, context, _ = stop.process!(tree_state, route)
            route.merge(changeset, stop) if context.success?
            populate_balancers(stop.balancers).each(&:apply!)
          end
        end

        private

        def populate_stops_with_sequence(stops)
          stop_for = ->(key) { "#{route.key.camelize}::Stops::#{key.camelize}Stop".constantize }
          route.sequence.map do |stop_key|
            next stop_for.call(stop_key) unless stop_key.is_a?(Array)

            stop_key.map { |key_entry| stop_for.call(key_entry) }
          end
        end

        def process_stops_with_reconciler(stops)
          reconciler = route.reconcilers.values.find { |reconciler| reconciler.sequence == stops.map(&:name) }
          reconciler.name.constantize.using(route).reconcile!(stops)
        rescue NameError
          nil
        end

        # def sort_stops_by_sequence(route)
        #   if route.sequence.empty?
        #     route.stops.values.sort_by(&:index)
        #   else
        #     route.sequence.map do |index|
        #     end
        #   end
        #   route.stops
        # end
      end
    end
  end
end
