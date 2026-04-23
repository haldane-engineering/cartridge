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
      def concurrently_execute_with_reconciliation!(actors)
        pool = Concurrent::FixedThreadPool.call(actors.count)
        promises = actors.map { |actor| Concurrent::Promises.future(executor: pool, &actor) }
        Concurrent::Promises.zip(*promises).value!
      end
    end
  end
end
