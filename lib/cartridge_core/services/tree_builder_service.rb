# frozen_string_literal: true

require 'digest'

module CartridgeCore
  module Services
    class TreeBuilderService
      include CartridgeCore::Errors::DynamicPropagation

      def self.build(key, **opts) = new(key, **opts).build

      def initialize(timeline_key, **options)
        @timeline_key = timeline_key
        @opts = default_builder_opts.merge(options)
        @cache = CartridgeCore::ICache.new
        @scheduled_execution = opts.dig(:scheduled_timeline_execution)
      end

      def build
        definition = (opts[:definitions] || preexisting_definitions).deep_symbolize_keys
        definition = definition.dig(:timelines, timeline_key)
        tree = Entities::Tree.new(**definition.slice(*Entities::Tree.base_keys)).tap do |tree|
          assign_timeline_context!(tree)
          confirm_executable_files!(tree.using_namespace(:routes, definition.dig(:routes).keys))
          build_and_assign_tree_routes!(tree, definition)
        end
        definition_json = definition.to_json
        _, tl_state = cache.timeline_state_for(Digest::MD5.hexdigest(definition_json), initial_definition: definition)
        # Scheduled executions are global objects, mostly independent of any state, but we also need to track it state wise
        # we use the execution to filter already run routes and stops as a continuity conduit. If no scheduled execution then
        # we initialize a new one without the id and go through with the rest of the process.
        tl_state = tl_state.merge(scheduled_timeline_executions: [
          *tl_state.fetch(:scheduled_timeline_executions, []), scheduled_execution.id,
        ]) if scheduled_execution.id
        ::CartridgeCore::Services::CacheActions::Load.apply!(tree, tl_state)
      end

      private

      attr_reader(*%i(timeline_key opts cache scheduled_execution))

      def default_builder_opts
        @default_builder_opts ||= {
          parameters:                   {},
          scheduled_timeline_execution: ::CartridgeCore::Entities::ScheduledTimelineExecution.new,
        }
      end

      def preexisting_definitions
        @preexisting_definitions ||= begin
          yaml_content = File.read(Rails.root.join('lib/cartridge_core/definitions/timelines.yml'))
          YAML.safe_load(yaml_content)
        end
      end

      def build_and_assign_tree_routes!(tree, definition)
        tree.routes = scheduled_execution.filter_routes(definition.dig(:routes)).keys.map do |r_key|
          # probably need to assign parameters someone here - confirm during run
          route_class = ::CartridgeCore::Entities::Route
          state_validation_mod = ::CartridgeCore::Entities::Concerns::StateIntegrityEnforcement
          route = route_class.new(**definition.dig(:routes, r_key).slice(*route_class.base_keys))
          # pass on tree context to route
          route_context_params = opts.dig(:parameters, route.name.to_sym) || {}
          route.context = CartridgeCore::Entities::Trees::Context.new(**route_context_params)
          # build reconcilers
          route.reconcilers = (definition.dig(:routes, r_key, :reconcilers) || {}).keys.map do |s_key|
            CartridgeCore::Entities::Reconciler.new(**definition.dig(:routes, r_key, :reconcilers, s_key))
          end
          # build checks and balancers for route
          route_path = [:routes, r_key]
          guard_entity_args = [route_path, tree, definition, state_validation_mod]
          route.checks, route.balancers = build_entity_guard_classes(*guard_entity_args, entity: route)
          # build stops
          path = [:routes, r_key, :stops]
          confirm_executable_files!(tree.using_namespace(definition.dig(*path).keys, group: path.join('/')))
          route.stops = scheduled_execution.filter_stops(definition.dig(:routes, r_key, :stops)).keys.map do |s_key|
            stop_path = [:routes, r_key, :stops, s_key]
            stop = CartridgeCore::Entities::Stop.new(**definition.dig(*stop_path).merge(route:))
            stop_guard_entity_params = [stop_path, tree, definition, state_validation_mod]
            stop.checks, stop.balancers = build_entity_guard_classes(*stop_guard_entity_params, entity: stop)
            stop
          end
        end
      end

      def build_entity_guard_classes(path, tree, definition, state_validation_mod, entity:)
        build_classes = ->(group) do
          path = path.map(&:to_sym)
          guard_definitions = definition.dig(*path, group)
          filter_valid_guards = ->(obj) { obj.values_at(%i(required using)).select(&:present?).presence }
          guard_files = guard_definitions.map(&filter_valid_guards).map(&method(:apply_namespace))
          # If the user specifies a check or balancer classes then make sure those files are present in the source.
          confirm_executable_files!(guard_files.compact)
          guard_definitions.zip(guard_files).map do |(obj, guard_file)|
            (guard_file ? guard_file.constantize : default_guard_class).new(**obj.slice(:required).merge(entity:)).tap do |klass|
              klass.class.include(state_validation_mod)
            end
          end
        end
        %i(checks balancers).map(&build_classes)
      end

      def assign_timeline_context!(tree)
        tree.context = CartridgeCore::Entities::Trees::Context.new(
          **opts.slice(*%i(parameters load_namespace)).merge(
            execution_context: scheduled_execution.serialized_context || {},
          ),
        )
      end

      def confirm_executable_files!(f_names)
        f_names.each { |f| halt!(:missing_source_file_error) unless defined?("::#{f}".camelize) }
      end

      def default_guard_class = ::CartridgeCore::Entities::Check

      def default_guard_file_name = default_guard_class.name.underscore

      def apply_namespace(fname)
        tree.using_namespace(*path, fname, group: path.join('/')) if fname
      end
    end
  end
end
