# frozen_string_literal: true

require 'find'

module Diderot
  module Routes
    module HighlightComposition
      module Services
        class ReplayCompositionService < BaseService
          include Diderot::Concerns::CommandTools::Python

          def self.call(**kwargs) = new(**kwargs).call

          # @param [::Diderot::Nba::Game] game
          # @param [::Diderot::Providers::Sportsradar::NBA] provider
          def initialize(game:, provider:)
            @game = game
            @provider = provider
          end

          def call
            safely_execute do
              dir_path = Digest::SHA256.hexdigest(@game.external_id)
              source_file = list_contained_files(Rails.root.join(dir_path)).first
              chunks_dir = FileUtils.mkdir_p(Rails.root.join("#{dir_path}/fragments"))
              game_logs = @provider.game_log_class.find_by(external_id: @game.external_id).raw_json
              # preselect the events: the preselection should return a list of Fragment objects
              # for nba highlights, I imagine we add a padding: 10 seconds after the previous event.
              # and 5 seconds into the next. These numbers should be configurable.
              # The current implementation naively adds 5 seconds pre and 3 seconds post event, which might work for now
              # but to make the highlights more fleshy, I imagine we want to change this. TODO: Add padding to start and end
              # each fragment
              fragments = @provider.generate_highlight_fragments(game_logs, Fragment).each do |fragment|
                # see notes on the various options here
                # https://www.baeldung.com/linux/ffmpeg-cutting-videos
                # https://medium.com/@taylorjdawson/splitting-a-video-with-ffmpeg-the-great-mystical-magical-video-tool-%EF%B8%8F-1b31385221bd
                cmd = <<~cmd
                  ffmpeg -i '#{source_file}' -ss '#{fragment.start}' -t '#{fragment.duration_in_seconds}' \
                   -map 0 -c:v libx264 -b:v 3M -c:a aac -ar 44100 -ac 2 -crf 22 \
                  -async 1 '#{chunks_dir.first}/#{fragment.slug}.mp4'
                cmd
                output, _, status = py_exec(cmd)
                # Idea here is that each highlightable event at this point of execution, has been spawn out to the destination folder.
                # we can conveniently write to the manifest the matching event title name and it cna then be found and added to the composition
                # queue.
                require 'pry'
                binding.pry
                raise unless status.success?

                fragment.set(success: status.success?, output:)
              end
              manifest_path = "#{dir_path}/manifest.txt"
              manifest_txt = fragments.filter(&:success).reduce('', &->(sum, fragment, index) {
                sum + "#{index.zero? ? "" : "\n"} file #{chunks_dir}/#{fragment.title.underscore}.mp4"
              })

              File.write(manifest_path, manifest_txt)
              f_path = "#{dir_path}/#{game.full_identifier}"
              output, _, _ = py_exec("ffmpeg -f concat -safe 0 -i #{manifest_path} -map 0 -c copy #{f_path}.mp4")
              succeed(output)
            end
          end

          private

          def list_contained_files(dir_path)
            Find.find(dir_path).select(&->(path) { File.file?(path) })
          end
        end

        Fragment = Struct.new(*%i(title start end output success), keyword_init: true) do
          def set(**attributes)
            attributes.entries { |(k, v)| send(:"#{k}=", v) }
            self
          end

          def start
            @start ||= to_h[:start].strftime('%H:%M:%S')
          end

          def duration_in_seconds
            @duration_in_seconds ||= (to_h[:end] - to_h[:start]).to_i
          end

          def slug
            @slug ||= title
              .downcase
              .gsub(/[^a-z0-9\s]/i, '')
              .strip
              .gsub(/\s+/, '-')
          end
        end
      end
    end
  end
end
