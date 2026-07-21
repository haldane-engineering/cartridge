# frozen_string_literal: true

module CartridgeCore
  module Entities
    # tree_state at this point  -> if reconciling for a route, should be a routes' slice of the
    # in the main tree state -> { current: { **contains  all the possible data keys  }, route_1:
    # {{ tree_state: { main: main_tree.current, initial: { *should be empty to begin with, but maybe we
    # can populate this from the config definition for any initializing varibles }  }
    # { current, }}
    # }
    Reconciler = Struct.new(*%i(route stops tree_state sequence), keyword_init: true) do
      # @param [Models::Stop] stops a list of stops we want execute concurrently
      # @returns [Models::Stop]
      def concurrently_execute_with_reconciliation!(actors, blocking = true)
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
