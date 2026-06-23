# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Trees
      Context = Struct.new(*%i(parameters load_namespace execution_context), keyword_init: true) do
        def using_namespace(*filenames, group: nil)
          filenames.map do |fname|
            '{load_namespace || ' + "}/#{group ? "#{group}/" : ""}#{fname}"
          end
        end
      end

      Parameters = OpenStruct.new do
        include ::CartridgeCore::Cache::Concerns::SelectivePersistence

        delegate :slice, to: :to_h
        delegate :dig, to: :to_h
        # example = get('source_population.available_games_retrieval.source_feed')
        def get(key) = dig(*key.split('.'))
        class << self; def wrap(value) = new(**value); end
      end
    end
  end
end
