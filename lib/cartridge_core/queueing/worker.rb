# frozen_string_literal: true

module CartridgeCore
  module Queueing
    CONTEXT_KEYS = %i(route stop scheduled_execution)
    class Worker
      ExecutionContext = Struct.new(*WORKER_KEYS, keyword_init: true) do
        def arguments
          @arguments ||= [scheduled_execution.id, route, stop, scheduled_at]
        end

        def load_namespace
          @load_namespace ||= route.context.load_namespace.to_s.camelize
        end

        def using
          @using ||= routes.context.parameters.fetch(:executes_schedules_with, :cartridge_scheduler)
        end
      end

      # @param [::Queueing::Entities::Worker::ExecutionContext] context contains all relevant information
      # for the scheduler to build and store a deferred execution.
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
        job_name = "CartridgeCore::#{context.load_namespace}::#{context.route.name}::#{context.stop.name}Job"
        # Cartridge workflows should be rails-based applications -> Using ApplicationJob.
        # The args here should always contain the scheduled at.
        worker_class ||= begin
          "CartridgeCore::Queueing::Runners::#{context.using.camelize}".runner
          worker_class.queue_as(:default)
          # args -> timeline_execution_id, route, stop, scheduled_at
          worker_class.define_method(:perform, &->(*args) {
            ::CartridgeCore::Services::Timelines::ScheduledExecutionResolver.new
            .resolve!([args.first])
          })
        rescue NameError
          ::CartridgeCore::Services::Timelines::ScheduledExecutionScheduler.new
        end
        dispatch_worker!(Object.const_set(job_name, worker_class), context)
        context.scheduled_execution
      end

      private

      def dispatch_worker!(worker, context)
        case context.using
        when :sidekiq || :resque || :solid_queue
          worker.set(wait_until: context.scheduled_at).perform_later(*context.arguments)
        else worker.perform(*context.arguments)
        end
      end
    end
  end
end
