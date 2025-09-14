# frozen_string_literal: true

module Timelines
  module Models
    # balancers and checks should inherit from this
    Guard = Struct.new do
      def effect(tree, &block)
        ctx = block.call
        # regardless of the status, ensure that you log it
        tree.register_activity!(:check_application_status_update, self, ctx:)
      end
    end
  end
end
