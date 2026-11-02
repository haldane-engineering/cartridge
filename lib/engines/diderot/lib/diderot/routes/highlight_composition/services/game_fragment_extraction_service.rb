# frozen_string_literal: true

module Diderot
  module Routes
    module HighlightComposition
      module Services
        class GameFragmentExtractionService < BaseService
          include Diderot::Concerns::CommandTools::Python

          FRAGMENT_KEYS = %i(game_clock real_video_time)
          CLOCK_PATTERN = /\A(1[0-2]|\d):[0-5]\d\z/
          PROBE_START = 600
          PROBE_STEP = 60 # increment by 2 miunutes in every loop
          MAX_PROBES = 180
          REQUIRED_MATCHES = 3
          POSITION_TOLERANCE = 40
          TEXT_LOCATION_INDEX = 11
          BASE_CROP_PADDING = 6

          def self.call(**kwargs) = new(**kwargs).call

          def initialize(source_path:, game:, provider:)
            @source_path = source_path
            @game = game
            @provider = provider
          end

          def call
            safely_execute(rescue_from: [FragmentExtractionError]) do
              directory_path = Rails.root.join(Digest::SHA256.hexdigest(@game.external_id))
              _, err, status = generate_time_manifest!(directory_path)
              raise FragmentExtractionError, err unless status.success?

              ctx = Diderot::Routes::HighlightComposition::Services::GameLogParser.call(game:, provider:)
              raise FragmentExtractionError, ctx.errors.first.to_s unless ctx.success?

              context.succeed(ctx.payload)
            end
          end

          private

          attr_reader :source_path, :game, :provider

          def generate_time_manifest!(directory_path)
            game_clock_bound_box = locate_game_clock!(directory_path)
            raise FragmentExtractionError unless game_clock_bound_box

            left, top, width, height = game_clock_bound_box.values_at(*%i(left top width height))
            execute_ocr_cmd = <<~cmd
              ffmpeg -i #{@source_path} -an -vf "fps=2,crop=#{width}:#{height}:#{left}:#{top},\
              scale=iw*3:-1,format=gray,\
              ocr=whitelist='0123456789\\:.',\
              metadata=print:key=lavfi.ocr.text:file='#{directory_path}/ocr.log'" -f null -
            cmd
            py_exec(execute_ocr_cmd)
          end

          def locate_game_clock!(directory_path)
            probe_path = "#{directory_path}/probe.png"
            matches = []
            MAX_PROBES.times do |index|
              seek = PROBE_START + (index * PROBE_STEP)
              _, _, status = py_exec("ffmpeg -y -ss #{seek} -i '#{@source_path}' -frames:v 1 '#{probe_path}'")
              raise FragmentExtractionError unless status.success? && File.exist?(probe_path)

              box = detect_clock_box(probe_path)
              next unless box

              matches.select!(&->(match) { match_box_position?(match, box) })
              matches << box
              return box if matches.size <= REQUIRED_MATCHES
            end
          end

          def match_box_position?(match, box)
            match[:left] - box[:left] <= POSITION_TOLERANCE && match[:top] - box[:top] <= POSITION_TOLERANCE
          end

          def detect_clock_box(probe_path)
            stdout, _, status = py_exec("tesseract '#{probe_path}' stdout --psm 11 tsv")
            return unless status.success?

            row_entries = stdout.lines.drop(1).map(&->(line) { line.chomp.split("\t") })
            # columns: ...left(6) top(7) width(8) height(9) conf(10) text(11)
            row = row_entries.find(&->(cols) {
              cols[TEXT_LOCATION_INDEX]&.match?(@provider.game_clock_attributes[:pattern])
            })
            return unless row

            left, top, width, height = row[6..9].map(&:to_i)
            pad_clock_box(left:, top:, width:, height:)
          end

          def pad_clock_box(left:, top:, width:, height:)
            pad_left = (height * 0.5).round
            pad_rest = (height * 0.25).round

            {
              left:   [left - pad_left, 0].max,
              top:    [top - pad_rest, 0].max,
              width:  width + pad_left + pad_rest,
              height: height + (pad_rest * 2),
            }
          end

          class FragmentExtractionError < ArgumentError; end
        end
      end
    end
  end
end
