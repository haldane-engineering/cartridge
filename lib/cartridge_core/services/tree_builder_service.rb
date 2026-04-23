# frozen_string_literal: true

require 'digest'

module CartridgeCore
  module Services
    class TreeBuilderService
      include CartridgeCore::Errors::Concerns::DynamicErrorPropagation

      def self.build(*args) = new(*args).build

      def initialize(timeline_key, **options)
        @timeline_key = timeline_key
        @opts = default_builder_opts.merge(options)
        @cache = CartridgeCore::ICache.new
      end

      def build
        definition = (opts[:definitions] || preexisting_definitions)[timeline_key]
        tree = Entities::Tree.new(**timeline_raw.slice(*Entities::Tree.base_keys)).tap do |tree|
          confirm_executable_files!(tree.using_namespace(definition.dig(:routes), :routes))
          assign_timeline_context!(tree)
          build_and_assign_tree_routes!(tree, definition)
        end
        definition_hash = Digest::MD5.hexdigest(definition.to_json)
        _, tl_state = cache.timeline_state_for(definition_hash)
        # load the state into the timeline instance
        ::CatridgeCore::Services::CacheActions::Load.apply!(tree, tl_state)
      end

      private

      attr_reader(*%i(timeline_key opts cache))

      def default_builder_opts
        @default_builder_opts ||= { parameters: {} }
      end

      def preexisting_definitions
        @preexisting_definitions ||= begin
          yaml_content = File.read(Rails.root.join('lib/cartridge_core/definitions/timelines.yml'))
          YAML.safe_load(yaml_content)
        end
      end

      def build_and_assign_tree_routes!(tree, definition)
        tree.routes = definition.dig(:routes).keys.map do |r_key|
          # probably need to assign parameters someone here - confirm during run
          route_class = ::CartridgeCore::Entities::Route
          state_validation_mod = ::CartridgeCore::Entities::Concerns::StateIntegrityEnforcement
          route = route_class.new(**definition.dig(:routes, r_key).slice(*route_class.base_keys))
          # pass on tree context to route
          route.context = CartridgeCore::Entities::Tree::Context.new(**(opts.dig(:parameters, route.name.to_sym) || {}))
          # build reconcilers
          route.reconcilers = definition.dig(:routes, r_key, :reconcilers).keys.map do |s_key|
            CartridgeCore::Entities::Reconciler.new(**definition.dig(:routes, r_key, :reconcilers, s_key))
          end
          # build stops
          path = [:routes, r_key, :stops]
          confirm_executable_files!(tree.using_namespace(definition.dig(*path).keys, group: path.join('/')))
          route.stops = definition.dig(:routes, r_key, :stops).keys.map do |s_key|
            stop = CartridgeCore::Entities::Stop.new(**definition.dig(:routes, r_key, :stops, s_key).merge(route:))
            stop.checks, stop.balancers = build_guard_classes_for_stop(stop, tree, definition, state_validation_mod)
            stop
          end
          # build route checks - TODO: DRY THIS
          path = [routes, r_key, :checks]
          confirm_executable_files!(tree.using_namespace(definition.dig(*path).pluck(:using), group: path.join('/')))
          route.checks = definition.dig(:routes, r_key, :checks).map do |check_obj|
            klass = tree.using_namespace([check_obj.dig(:using)], group: path.join('/')).first
            klass = klass.camelize.constantize
            klass.new(required: check_obj.dig(:required), entity: route).class.include(state_validation_mod)
          end
          # build route balancers
          path = [:routes, r_key, :balancers]
          confirm_executable_files!(tree.using_namespace(definition.dig(*path).pluck(:using), group: path.join('/')))
          route.balancers = definition.dig(:routes, r_key, :balancers).map do |balancer_obj|
            klass = tree.using_namespace([balancer_obj.dig(:using)], group: path.join('/')).first
            klass = klass.camelize.constantize
            klass.new(required: balancer_obj.dig(:required), entity: route).class.include(state_validation_mod)
          end
        end
      end

      def build_guard_classes_for_stop(stop, tree, definition, state_validation_mod)
        build_classes = ->(group) do
          path = [:routes, stop.route.name, :stops, stop.name, group]
          confirm_executable_files!(tree.using_namespace(definition.dig(*path).pluck(:using), group: path.join('/')))
          definition.dig(*group_path).map do |obj|
            klass = tree.using_namespace([obj.dig(:using)], group: path.join('/')).first.camelize.constantize
            klass.new(required: obj.dig(:required), entity: stop).class.include(state_validation_mod)
          end
        end
        %i(checks balancers).map(&build_classes)
      end

      def assign_timeline_context!(tree) = tree.context = CartridgeCore::Entities::Tree::Context.new(**opts)

      def confirm_executable_files!(f_names)
        f_names.each { |f| halt!(:missing_source_file_error) unless defined?("::#{f}".camelize) }
      end
    end
  end
end
