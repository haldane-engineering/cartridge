# frozen_string_literal: true

module Timelines
  module Models
    Change = Struct.new(*TREE_KEYS, keyword_init: true)
  end
end
