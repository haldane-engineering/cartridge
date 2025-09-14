# frozen_string_literal: true

module Timelines
  class RegisterActivityService < BaseService
    def initialize(activity, object, timeline:)
      @activity = activity
      @object = object
      @timeline = timeline
    end

    def call
      # Logic here is to update the logs associated with the timeline
      #
    end
  end
end
