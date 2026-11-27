# frozen_string_literal: true

module Diderot
  module Concerns
    module ExternalRequestCacheable
      def cache_request(cache_key, &block)
        yield_response = ->() {
          response = block.call
          [response.success?, response.body]
        }
        cache!(cache_key, &yield_response)
      end

      def cache_stream!(cache_key, &block)
        yield_stream = lambda {
          io = StringIO.new
          io.binmode
          response = block.call(io)
          [response.success?, io.string]
        }
        cache!(cache_key, &yield_stream)
      end

      private

      def cache!(cache_key, &yield_response)
        # We assume that the block passed yields a httparty response object
        # we cache the status (not code - true or false) and the body.
        # Only cache successful responses
        # Alternatively I could use Rails.cache.fetch, nil responses skip caching
        #    Rails.cache.fetch(cache_key, expires_in:) do
        #   response = block.call
        #   bind
        #   response.body if response.success?
        # end
        #
        cached_response_value = Rails.cache.read(cache_key)
        return yield_response.call.tap(&->(response) {
          Rails.cache.write(cache_key, response)
        }) if !cached_response_value || !cached_response_value.first

        cached_response_value
      end
    end
  end
end
