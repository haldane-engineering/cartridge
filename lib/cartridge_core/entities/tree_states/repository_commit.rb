# frozen_string_literal: true

module CartridgeCore
  module Entities
    module TreeStates
      RepositoryCommit = Struct.new(*%i(id commit applied applied_at), keyword_init: true) do
        include ::CartridgeCore::Cache::Concerns::SelectivePersistence
        persists!(*%i(id commit applied applied_at))
      end
    end
  end
end
