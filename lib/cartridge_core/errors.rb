# frozen_string_literal: true

module CartridgeCore
  module Errors
    module DynamicPropagation
      def halt!(error_key, message = nil)
        error_class = define_error!(error_key)
        raise error_class.new(message || error_key)
      end

      # @param [Struct] entity - any error-prone timeline object (Route, Stop, timeline itself and checks)
      # @param [Symbol] the error key, it is dynamically transformed to a new error class
      # @param [Array<String>] messages
      # @return [Core::Context]
      def fail!(entity, error_key, errors)
        ctx = entity.context || context
        error_class = define_error!(error_key)
        error_messages = errors.map(&->(error) { error.full_message(highlight: false) }).join('\n')
        ctx.fail!(error: error_class.new(error_messages))
        entity.with_context(ctx)
      end

      private

      def define_error!(error_key)
        self.class.class_eval <<-RUBY
          class #{error_key.to_s.camelize} < StandardError; end
        RUBY
        "#{self.class.name}::#{error_key.to_s.camelize}".constantize
      end
    end
  end
end
