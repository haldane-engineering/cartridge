# frozen_string_literal: true

module Diderot
  module Concerns
    module MetadataRetrievable
      
      def meta(key) = metadata.dig(*key.split('.'))
    end
  end
end
