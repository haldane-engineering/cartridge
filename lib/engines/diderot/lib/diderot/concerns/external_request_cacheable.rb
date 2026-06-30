# frozen_string_literal: true

require 'open3'

module Diderot
  module Concerns
    module ExternalRequestCacheable
      def cache_request(cache_key, &block)
        # We assume that the block passed yields a httparty response object
        # we cache the status (not code - true or false) and the body.
        # Only cache successful responses
        # Alternatively I could use Rails.cache.fetch, nil responses skip caching
        #    Rails.cache.fetch(cache_key, expires_in:) do
        #   response = block.call
        #   bind
        #   response.body if response.success?
        # end
        cached_response_value = Rails.cache.read(cache_key)
        yield_response = ->() {
          response = block.call
          [response.success?, response.body]
        }

        return yield_response.call.tap(&->(response) {
          Rails.cache.write(cache_key, response)
        }) if !cached_response_value || !cached_response_value.first

        cached_response_value
      end
    end
  end
end
