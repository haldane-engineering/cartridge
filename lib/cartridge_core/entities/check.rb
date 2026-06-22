# frozen_string_literal: true

module CartridgeCore
  module Entities
    Check = Struct.new(*%i(name entity required), keyword_init: true) do
      include ::CartridgeCore::Entities::Concerns::StateIntegrityEnforcement
    end
  end
end
