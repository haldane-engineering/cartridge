# frozen_string_literal: true

module CartridgCore
  module Services
    module Concerns
      module ConcurrentExecution
        def concurrently_execute_with_reconciliation!(actors, blocking:)
          pool = Concurrent::FixedThreadPool.new(actors.count)
          promises = actors.map { |actor| Concurrent::Promises.future(&actor) }
          return Concurrent::Promises.zip(*promises).value if blocking

          Concurrent::Promises.zip(*promises).on_fulfilment { shutdown!(pool) }
          promises
        rescue
          shutdown!(pool)
        end

        private

        def shutdown!(pool)
          if pool
            pool.shutdown
            pool.wait_for_termination
          end
        end
      end
    end
  end
end
