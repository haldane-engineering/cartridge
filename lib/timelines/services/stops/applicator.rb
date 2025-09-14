# frozen_string_literal: true

module Stops
  class Applicator < BaseService
    def initialize(stop)
      @stop = stop
    end

    def call
      # stops receive input and send them out as payload
      # right
    end
  end
end
