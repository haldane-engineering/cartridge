# frozen_string_literal: true

module CartridgeCore
  module Queueing
    WORKER_CONTEXT_KEYS = %i(route stop scheduled_execution scheduled_at)
    class Worker
      def self.spawn!(*args) = new.spawn!(*args)

      # @param [::Queueing::Entities::Worker::ExecutionContext] context contains all relevant information
      # for the scheduler to create a deferred execution.
      def spawn!(context)
        # This is a temporary solution for monitoring trees while we build out the resolver interface
        # for now - we can monitor the current state of all scheduled executions using the inherent
        # queueing backend of the parent application. Diderot currently uses sidekiq. However the main stay
        # of intended execution is the scheduledresolver runner. Cartridge workflow apps will have a config/cartridge.rb
        # and an initializers/cartridge.rb. Config specifies the queing backend (cartridge's runner or a 3p engine).
        # the initializer script starts the resolver, intermittently checks for unresolved executions,
        # and executes them.
        #
        # example: ::CartridgeCore::Diderot::SourcePopulation::AvailableGamesRetrievalJob
        job_name = "#{context.stop.name.camelize}Job"
        route_module = "::#{context.load_namespace}::Routes::#{context.route.name.camelize}".constantize
        # Cartridge workflows should be rails-based applications -> Using ApplicationJob.
        # The args here should always contain the scheduled at.
        worker_class ||= begin
          # check if we have the queue runner in our list, raises if not. In that case we use our native scheduler.
          "::CartridgeCore::Queueing::Runners::#{context.using.to_s.camelize}".constantize.runner.tap do |klass|
            klass.queue_as(:default)
            # args -> timeline_execution_id, route, stop, scheduled_at
            klass.define_singleton_method(:perform, &->(*args) {
              ::CartridgeCore::Services::Timelines::ScheduledExecutionResolver.new
              .resolve!([args.first])
            })
          end
        rescue NameError
          ::CartridgeCore::Services::Timelines::ScheduledExecutionScheduler.new
        end
        dispatch_worker!(route_module.const_set(job_name, worker_class), context)
        context.scheduled_execution
      end

      private

      def dispatch_worker!(worker, context)
        case context.using
        when :sidekiq
          worker.perform_at(context.scheduled_at, context.arguments.first)
        when :resque || :solid_queue
          worker.set(wait_until: context.scheduled_at).perform_later(context.arguments.first)
        else
          worker.perform(*context.arguments)
        end
      end

      ExecutionContext = Struct.new(*WORKER_CONTEXT_KEYS, keyword_init: true) do
        def arguments
          @arguments ||= [scheduled_execution.id, route, stop, scheduled_at]
        end

        def load_namespace
          @load_namespace ||= route.context.load_namespace.to_s.camelize
        end

        def using
          @using ||= route.context.parameters.fetch(:executes_schedules_with, :cartridge_scheduler)
        end
      end
    end
  end
end
