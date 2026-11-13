# frozen_string_literal: true

module CartridgeCore
  module Queueing
    module Entities
      WORKER_KEYS = %i(route stop context args scheduled_execution_id)
      Worker = Struct.new(*WORKER_KEYS, keyword_init: true) do
        include ::CartridgeCore::Queueing::Concerns::EngineInference
        def spawn!(**opts)
          # This is a temporary solution to monitoring trees while we build out the resolver interface
          # for now - we can monitor the current state of all scheduled executions using the inherent
          # queueing backend of the parent application. Diderot currently uses sidekiq. However the main stay
          # of intended execution is the scheduledresolver runner. Cartridge workflow apps will have a config/cartridge.rb
          # and an initializers/cartridge.rb. Config specifies the queing backend (cartridge's runner or a 3p engine).
          # in the initializer script strarts the resolver, intermittently checks for unresolved executions ->
          #
          # example: ::CartridgeCore::Diderot::SourcePopulation::AvailableGamesRetrievalJob
          job_name = "CatridgeCore::#{context[:namespace].to_s.camelize}::#{route.name}::#{stop.name}Job"
          infer_queueing_backend.tap do |backend|
            worker_klass, _ = backend.build_worker_klass!
            worker_klass.define_method(:perform) do |*__args|
              super(*__args)
              ::CartridgeCore::Services::Timelines::ScheduledExecutionResolver.new(*args).run!
            end
            Object.const_set(job_name, worker_klass).perform(**context[:executor_opts])
          end
        end
      end
    end
  end
end
