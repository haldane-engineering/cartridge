# frozen_string_literal: true

# The Context class is used to encapsulate the result of a service operation,
# holding information about success, errors, messages, and any relevant payload.
module CartridgeCore
  module Services
    module Core
      class Context
        attr_reader :success, :errors, :messages, :payload

        # Initializes a new Context instance.
        #
        # @return [void]
        def initialize
          @success = true
          @errors = []
          @messages = []
        end

        # Marks the context as failed, recording the provided error.
        #
        # @param [StandardError] error The error that caused the failure.
        # @return [Context] The current context instance.
        def fail!(error:)
          @success = false
          @errors = [error]

          self
        end

        # Marks the context as successful, optionally providing a payload.
        #
        # @param [Object] payload The payload to be returned on success (default is nil).
        # @return [Context] The current context instance.
        def succeed(payload = nil)
          clear_errors
          @success = true
          @payload = payload

          self
        end

        # Sets the payload and clears any errors.
        #
        # @param [Object] payload The payload to set.
        # @return [Context] The current context instance.
        def payload!(payload:)
          @errors = []
          @payload = payload
        end

        # Checks if the operation was successful.
        #
        # @return [Boolean] True if the operation was successful; otherwise, false.
        def success?
          @success
        end

        # Returns a message string, combining messages or errors based on success state.
        #
        # @return [String] The combined success messages or error messages.
        def message
          success ? messages.join(', ') : errors.map(&:message).join(', ')
        end

        private

        # Clears the recorded errors in the context.
        #
        # @return [void]
        def clear_errors
          @errors = []
        end
      end
    end
  end
end
