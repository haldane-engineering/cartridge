# frozen_string_literal: true

module CartridgeCore
  module Entities
    Definition = Struct.new(*%i(raw id timestamp name)) do
      include ::CartridgeCore::Cache::Concerns::SelectivePersistence
      persists!(*%i(raw id timestamp name))
    end
  end
end
