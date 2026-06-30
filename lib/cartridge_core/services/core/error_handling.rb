# frozen_string_literal: true

# The ErrorHandling module provides mechanisms for managing errors
# within service classes. It includes methods for safely executing
# blocks of code and handling known error classes.
module CartridgeCore
  module Services
    module Core
      module ErrorHandling
        # A list of error classes that can be rescued during safe execution.
        ERROR_CLASSES = [
          ActiveRecord::RecordNotFound,
          ActiveRecord::RecordInvalid,
          ActiveModel::UnknownAttributeError,
          ActiveRecord::StatementInvalid,
          BaseService::InvalidInputError,
          BaseService::ServiceError,
        ].freeze

        # Safely executes a block of code, running checks if needed.
        #
        # @yield [void] The block of code to execute.
        # @return [Context] The context after execution.
        def safely_execute(&block)
          run_checks! if should_run_checks?
          block.call
          context
        rescue *ERROR_CLASSES => e
          fail!(error: e)
        end

        # Runs input validation checks. Must be implemented by the including class.
        #
        # @raise [NotImplementedError] When not implemented in a subclass.
        def run_checks!
          raise Services::Base::InvalidInputError, input.errors.flat_map(&:message) unless input.valid?
        end

        module Validatable
          module ClassMethods
            # Indicates that checks should be performed on input validation.
            #
            # @return [void]
            def performs_checks
              @should_run_checks = true
            end

            attr_reader :should_run_checks
          end

          # Checks if validation checks should be performed.
          #
          # @return [Boolean] True if checks should be performed; otherwise, false.
          def should_run_checks?
            self.class.should_run_checks
          end

          # Includes core error handling functionality and class methods.
          #
          # @param [Class] base The class to include the module in.
          def self.included(base)
            base.include(Core)
            base.extend(ClassMethods)
          end

          # Raises a service error with the specified message.
          #
          # @param [String] message The error message to raise.
          # @raise [BaseService::ServiceError] The raised error.
          def raise_error!(message)
            raise Services::Base::ServiceError, message
          end
        end
      end
    end
  end
end
