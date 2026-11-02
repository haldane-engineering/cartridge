# frozen_string_literal: true

module Diderot
  module Providers
    module Replays
      class Crackstreams
        include ::Diderot::Providers::Replays::Concerns::ContentStreamable

        def self.call(game, **opts) = new(game, **opts).call

        private

        def configuration
          @configuration ||= {
            url:                'https://crackstreams.mx',
            nba_anchor_href:    '/league/nbaregular66',
            stream_load_buffer: 6.seconds,
            unmute_button_text: 'UNMUTE_ME',
          }
        end
      end
    end
  end
end
