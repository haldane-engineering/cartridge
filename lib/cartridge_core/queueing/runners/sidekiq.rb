# frozen_string_literal: true

module CartridgeCore
  module Queueing
    module Runners
      class Sidekiq < CartridgeCore::Queueing::Engines::Base
        class << self
          def runner
            Class.new(ApplicationJob).tap do |klass|
              klass.include(Sidekiq::Job)
            end
          end
        end
      end
    end
  end
end
