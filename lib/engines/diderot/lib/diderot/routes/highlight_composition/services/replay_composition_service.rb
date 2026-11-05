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
            safely_execute(rescue_from: [ReplayCompositionError]) do
              # dir_path here is the hashed id of the game - which serves as a store for all the files
              # during the composition process -> at this point the preceeding stop (source_population#game_replays_retriever)
              # should have populated it with the source file.
              dir_path = Digest::SHA256.hexdigest(@game.external_id)
              source_file = list_contained_files(Rails.root.join("#{Digest::SHA256.hexdigest(@game.external_id)}/source")).first
              chunks_dir = FileUtils.mkdir_p(Rails.root.join("#{dir_path}/fragments"))
              game_logs = @provider.game_log_class.find_by(external_id: @game.external_id).raw_json
              extract_args = { source_path: source_file, game: @game, provider: @provider }
              ctx = ::Diderot::Routes::HighlightComposition::Services::GameFragmentExtractionService.call(**extract_args)
              return context.fail!(error: ctx.errors.first) unless ctx.success?

              highlight_generation_args = { fragment_class: Fragment, game_logs:, timestamps: ctx.payload }
              # preselect the events: the preselection should return a list of Fragment objects
              # for nba highlights, I imagine we add a padding: 10 seconds after the previous event.
              # and 5 seconds into the next. These numbers should be configurable.
              # The current implementation naively adds 5 seconds pre and 3 seconds post event, which might work for now
              # but to make the highlights more fleshy, I imagine we want to change this. TODO: Add padding to start and end
              # each fragment
              fragments = @provider.generate_highlight_fragments(**highlight_generation_args).select(&:success?).each do |fragment|
                # see notes on the various options here
                # https://www.baeldung.com/linux/ffmpeg-cutting-videos
                # https://medium.com/@taylorjdawson/splitting-a-video-with-ffmpeg-the-great-mystical-magical-video-tool-%EF%B8%8F-1b31385221bd
                cmd = <<~cmd
                  ffmpeg -i '#{source_file}' -ss '#{fragment.start}' -t '#{fragment.duration_in_seconds}' \
                   -map 0 -c:v libx264 -b:v 3M -c:a aac -ar 44100 -ac 2 -crf 22 \
                  -async 1 '#{chunks_dir.first}/#{fragment.slug}.mp4'
                cmd
                output, err, status = py_exec(cmd)
                raise ReplayCompositionError.new, err unless status.success?

                fragment.set(success: status.success?, output:)
              end
              manifest_path = "#{dir_path}/manifest.txt"
              manifest_txt = fragments.filter(&:success?).each_with_index.reduce('', &->(sum, (fragment, index)) {
                sum += "#{index.zero? ? "" : "\n"} file #{chunks_dir.first}/#{fragment.slug}.mp4"
                sum
              })
              File.write(manifest_path, manifest_txt)
              FileUtils.mkdir_p("#{dir_path}/dest/")
              f_path = "#{dir_path}/dest/#{game.full_identifier}"
              _, err, status = py_exec("ffmpeg -f concat -safe 0 -i #{manifest_path} -map 0 -c copy '#{f_path}.mp4'")
              return context.fail!(error: ReplayCompositionError.new(err)) unless status.success?

              succeed(@game.id)
            end
          end

          private

          attr_reader :game

          def list_contained_files(dir_path)
            Find.find(dir_path).select(&->(path) { File.file?(path) })
          end

          class ReplayCompositionError < StandardError; end
        end

        # TODO: refactor to Entities::Fragment
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
