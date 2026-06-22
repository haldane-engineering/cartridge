# frozen_string_literal: true

module Services
  module Core
    class Balancer < BaseService
      class MissingChangesetKeyError < StandardError; end
      class MissingStepError < StandardError; end

      def self.apply!(*args)
        new(*args).apply!
      end

      def initialize(check, entity, timeline:)
        @check = check
        @entity = ::CartridgeCore::Entities::Core::CheckableEntity.decorate(entity)
        @timeline = timeline
      end

      def apply!
        # tree looks something like this at this point
        # simple implementation is to check the keys are present and not nil
        # check that the preceeding stop/route has also been applied
        # check that the step before has been run as well
        timeline.register_activity!(check, :check_application_start)
        # check that the precceeding step was applied correctly
        # preceeding_step_applied should return true if it's in concurrent group
        raise MissingStepError unless entity.preceeding_step_applied?

        # check that the required keys are relevant for the step to run are present in the current tree state
        check.required.each do |_check_entry_key|
          raise MissingChangesetKeyError unless entity.tree_state.current[check_entry__key].present?
        end
      ensure
        timeline.register_activity!(check, :check_application_end)
      end

      private

      attr_reader :entity, :check
    end
  end
end
