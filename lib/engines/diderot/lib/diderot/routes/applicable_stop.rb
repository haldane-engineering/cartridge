# frozen_string_literal: true

module Diderot
  module Routes
    class ApplicableStop < ::CartridgeCore::Entities::Core::Stop
      include ::Diderot::Concerns::ProviderSelection
    end
  end
end
