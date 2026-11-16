# frozen_string_literal: true

require 'sidekiq'
module CartridgeCore
  module Queueing
    module Runners
      class Sidekiq < CartridgeCore::Queueing::Runners::Base
        class << self
          def runner
            Class.new.tap do |klass|
              klass.include(::Sidekiq::Job)
            end
          end
        end
      end
    end
  end
end
