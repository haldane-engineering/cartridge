# frozen_string_literal: true

module CartridgeCore
  module Entities
    module Trees
      Context = Struct.new(*%i(parameters load_namespace execution_context), keyword_init: true) do
        def using_namespace(*filenames, group: nil)
          filenames.map do |fname|
            "#{load_namespace ? "#{load_namespace}/" : ""}#{group ? "#{group}/" : ""}#{fname}"
          end
        end
      end
    end
  end
end
