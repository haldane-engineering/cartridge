# frozen_string_literal: true

module Timelines
  module Models
    STATE_KEYS = %i[version current final changes id branches]
    TreeState < Struct.new(*STATE_KEYS, keyword_init:) do
      def persist!(strategy)
        # for now we're just going to write to cache
        # we'll send this to the various database engines and
        # build a reader from that
      end
    end
  end
end
