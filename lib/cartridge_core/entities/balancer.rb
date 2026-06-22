# frozen_string_literal: true

module CartridgeCore
  module Entities
    Balancer = Struct.new(*%i(name entity), keyword_init: true) do
      include ::CartridgeCore::Entities::Concerns::StateIntegrityEnforcement
      guard_type :balancer
    end
  end
end
