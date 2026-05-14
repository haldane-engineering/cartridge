# frozen_string_literal: true

module CartridgeCore
  module Errors
    module DynamicPropagation
      def halt!(error_key, message = nil)
        error_key = error_key.to_s
        self.class.class_eval <<-RUBY
          class #{error_key.camelize} < StandardError; end
        RUBY
        "#{self.class.name}::#{error_key.camelize}".constantize.new(message || error_key)
      end
    end
  end
end
