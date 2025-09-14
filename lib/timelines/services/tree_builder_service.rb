# frozen_string_literal: true

module Timelines
  module Services
    class TreeBuilderService < BaseService
      def self.build(timeline) = new(timeline).build

      def initialize(timeline_key, options: nil)
        @timeline_key = timeline_key
        @options = options
      end

      def build
        yaml_content = File.read(Rails.root.join('lib/timelines/definitions.yml'))
        timeline_raw = YAML.safe_load(yaml_content)[timeline_key]

        @timeline = Models::Tree.new(**timeline_raw.slice(*Models::Tree.base_keys)).tap do |tree|
          collate_executable_files!(tree.dig(:routes).values)
          build_and_assign_tree_routes!(tree)
          # essentially check that all the requested files and folders exist
          # so we dont have any issues during orchestration
          run_structural_integrity_checks!(tree)
          inject_tree_state!(tree)
        end

        private

        attr_reader :sources, :options, :timeline_key

        def build_and_assign_tree_routes!(tree)
          tree.routes = tree.routes.keys.map do |r_key|
            route = ::Models::Route.new(**tree.routes[r_key].slice(*Models::Route.base_keys))
            # take all the nested files defined in the route's subtree, use them for validation
            collate_executable_files!(tree.routes.dig(r_key, :stops).values)
            route.stops = build_stops_for_route(route)
            route
          end
        end

        def inject_tree_state!(tree)
          # my thinking here really is to build a sort of slot system for the routes and contained stops
          # (deeply nested too) within the state, every (process and its subs) check that the
          # tree state is aware of it's presence before suggesting changes
          # something like branches, but already known
          # wish I could implement some cooler data structure for this - TODO
          tree.tree_state = ::Models::TreeState.new
          tree
        end

        def build_stops_for_route(route)
          route.stops.keys.map do |s_key|
            ::Models::Stop.new(**route.stops[s_key])
          end
        end

        def collate_executable_files!(files_source)
          @sources << files_source.flat_map do |source|
            # currrently only storing source files in the `using` attribute for checks and balances
            # in the future, this could change, as it seems sensible to me right now, that even timelines
            # themselves, could have checks and balances
            %i[balance checks].map do |source_key|
              source.dig(source_key, :using)
            end
          end
        end

        def run_structural_integrity_checks!(_tree)
          raise NotImplementedError
        end

        def run_structural_integrity_checks!
          # first of all, I think just implementation wise, this is not the best approach,
          # it doesnt make sense to get all the files
          # maybe camelize
          raise_error!(error(:incomplete_source_files_error)) if source_files.any?(&method(:missing_source_file?))
        end

        def missing_source_file?(source)
          defined?(source.camelize.constantize)
        rescue NameError
          false
        end
      end
    end
  end
end
