# frozen_string_literal: true

module Diderot
  module Concerns
    module ExternalRequestable
      def exec_request(url, body = {}, method:)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        response = http.request(request_from_url(uri, body, method:))
        [response.is_a?(Net::HTTPSuccess), JSON.parse(response.read_body)]
      end

      def request_from_url(url, body, method:)
        const_get("Net::HTTP::#{method.capitalize}").new(url).tap do |request|
          request['Content-Type'] = 'application/json'
          request.body = body.to_json
        end
      end
    end
  end
end
