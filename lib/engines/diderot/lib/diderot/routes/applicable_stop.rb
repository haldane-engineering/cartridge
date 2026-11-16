# frozen_string_literal: true

module Diderot
  module Routes
    class ApplicableStop < ::CartridgeCore::Entities::Core::Stop
      include ::Diderot::Concerns::ProviderSelection

      def leaf_name
        @leaf_name ||= name.split('::').last.underscore
      end
    end
  end
end
