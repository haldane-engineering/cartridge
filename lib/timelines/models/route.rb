# frozen_string_literal: true

module Timelines
  module Models
    ROUTE_KEYS = %i[]
    Route = Struct.new(*ROUTE_KEYS, keyword_init: true)
  end
end
