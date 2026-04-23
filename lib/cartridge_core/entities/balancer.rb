# frozen_string_literal: true

module CartridgeCore
  module Entities
    Balancer = Struct.new(*%i(name entity), keyword_init: true) do
      include StateIntegrityEnforcement
      guard_type :check
    end
  end
end
