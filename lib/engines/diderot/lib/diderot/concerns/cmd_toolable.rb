# frozen_string_literal: true

require 'open3'

module Diderot
  module Concerns
    module CmdToolable
      def command_exists?(cmd) = system("type #{cmd} > /dev/null 2>&1")
    end
  end
end
