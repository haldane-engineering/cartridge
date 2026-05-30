# frozen_string_literal: true

require 'open3'

module Diderot
  module Concerns
    module CommandTools
      module Python
        include CmdTools
        def py_exec(cmd)
          # for example "yt-dlp -P #{tmpdir} #{download_url}" -> yt-dlp
          cmd_bin = cmd.split(' ').first
          unless command_exists?(cmd_bin)
            unless command_exists?('uv')
              %x(curl -LsSf https://astral.sh/uv/install.sh | sh')
            end
            system("uv tool install #{cmd_bin}")
          end
          Open3.capture3(cmd)
        end
      end

      module Brew
        include CmdTools

        def exec(cmd, bin = nil)
          bin ||= cmd.split(' ').first
          unless command_exists?(bin)
            unless command_exists?('brew')
              # install brew
              %x(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
              # append brew to path
              %x(
              if [[ "$SHELL" == */zsh ]]; then
                PROFILE_FILE="$HOME/.zprofile"
              elif [[ "$SHELL" == */bash ]]; then
                PROFILE_FILE="$HOME/.bash_profile"
              else
                PROFILE_FILE="$HOME/.profile"
              fi

              if [[ "$(uname -s)" == "Darwin" ]]; then
                BREW_PATH="/opt/homebrew"
              else
                BREW_PATH="/home/linuxbrew/.linuxbrew"
              fi
              echo "eval \"\$($BREW_PATH/bin/brew shellenv)\"" >> "$PROFILE_FILE"
              eval "$($BREW_PATH/bin/brew shellenv)"
              )
            end
            system("HOMEBREW_NO_AUTO_UPDATE=1 brew install #{bin}")
          end
          Open3.capture3(cmd)
        end
      end

      module CmdTools
        def command_exists?(cmd) = system("type #{cmd} > /dev/null 2>&1")
      end
    end
  end
end
