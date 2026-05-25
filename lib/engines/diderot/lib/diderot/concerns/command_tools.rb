# frozen_string_literal: true

require 'open3'

module Diderot
  module Concerns
    module CommandTools
      module Python
        def py_exec(cmd)
          # for example "yt-dlp -P #{tmpdir} #{download_url}" -> yt-dlp
          cmd_bin = cmd.split(' ').first
          unless command_exists?(cmd_bin)
            unless command_exists?('uv')
              %x(curl -LsSf https://astral.sh/uv/install.sh | sh')
            end
            system("uv tool install #{cmd_bin}")
          end
          # this should take quite some time to complete downloading
          Open3.capture3(cmd)
        end

        def command_exists?(cmd) = system("type #{cmd} > /dev/null 2>&1")
      end
    end
  end
end
