# frozen_string_literal: true

module Timelines
  module Models
    TREE_KEYS = []
    Tree = Struct.new(*TREE_KEYS, keyword_init: true)
  end
end
