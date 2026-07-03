# frozen_string_literal: true

module CartridgeCore
  module Refinements
    module HashRefinement
      refine Hash do
        def deep_transform(&block)
          transform = lambda do |value|
            if value.is_a?(Hash)
              value.deep_transform(&block)
            elsif value.is_a?(Array)
              value.map(&transform)
            elsif value.is_a?(Struct)
              block.call(value)
            else
              value
            end
          end
          entries.map(&->((k, v)) { [k, transform.call(v)] }).to_h
        end
      end
    end
  end
end
