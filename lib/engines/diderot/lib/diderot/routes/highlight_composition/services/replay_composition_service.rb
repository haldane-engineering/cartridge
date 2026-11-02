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
              source_file = list_contained_files(Rails.root.join("#{Digest::SHA256.hexdigest(@game.external_id)}/source")).first
              chunks_dir = FileUtils.mkdir_p(Rails.root.join("#{dir_path}/fragments"))
              game_logs = @provider.game_log_class.find_by(external_id: @game.external_id).raw_json
              extract_args = { source_path: source_file, game: @game, provider: @provider }
              ctx = ::Diderot::Routes::HighlightComposition::Services::GameFragmentExtractionService.call(**extract_args)
              return context.fail!(error: ctx.errors.first) unless ctx.success?

              highlight_generation_args = { fragment_class: Fragment, game_logs:, timestamps: ctx.payload }
              fragments = @provider.generate_highlight_fragments(**highlight_generation_args).select(&:success?).each do |fragment|
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

          attr_reader :game

          def list_contained_files(dir_path)
            Find.find(dir_path).select(&->(path) { File.file?(path) })
          end
        end

        Fragment = Struct.new(*%i(description start stop output success period status), keyword_init: true) do
          def set(**attributes)
            attributes.entries { |(k, v)| send(:"#{k}=", v) }
            self
          end

          def success?
            @status != :failed
          end

          def duration_in_seconds
            @duration_in_seconds ||= (to_h[:stop] - to_h[:start]).to_i
          end

          def assign_attributes!(**attributes)
            attributes.entries.each do |(key, value)|
              send(:"#{key}=", value)
            end
            self
          end

          def fail!
            @status = :failed
            self
          end

          def destination
            @destination = period ? "#{period + 1}/#{slug}" : slug
          end

          def slug
            @slug ||= description
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
