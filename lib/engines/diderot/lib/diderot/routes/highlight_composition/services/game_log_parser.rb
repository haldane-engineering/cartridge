# frozen_string_literal: true

module Diderot
  module Routes
    module HighlightComposition
      module Services
        class GameLogParser < BaseService
          FRAGMENT_KEYS = %i(game_clock real_video_time)
          BEGIN_FRAGMENT_IDENTIFIER = 'frame:'
          GAME_CLOCK_IDENTIFIER = 'lavfi.ocr.text'

          def self.call(**kwargs) = new(**kwargs).call

          def initialize(game:)
            @game = game
            @fragments = []
          end

          def call
            safely_execute do
              directory_path = Rails.root.join(Digest::SHA256.hexdigest(@game.external_id))
              File.readlines("#{directory_path}/ocr.log", chomp: true).each.with_index do |line|
                if line.starts_with?(BEGIN_FRAGMENT_IDENTIFIER)
                  @fragment = assign_video_time!(line, Fragment.new)
                elsif line.starts_with?(GAME_CLOCK_IDENTIFIER)
                  fragment = assign_game_clock!(line, @fragment)
                  @fragments.push(fragment) if fragment.complete?
                end
              end
              context.succeed(@fragments)
            end
          end

          Fragment = Struct.new(*FRAGMENT_KEYS, keyword_init: true) do
            def complete? = game_clock && real_video_time
          end

          private

          attr_reader

          def assign_video_time!(line, fragment)
            matches = line.match(/pts_time:(\d+(?:\.\d+)?)/)
            fragment.real_video_time = matches[1] if matches.present?
            fragment
          end

          def assign_game_clock!(line, fragment)
            matches = line.match(/lavfi\.ocr\.text=(\d+:\d+|\d+\.\d+)/)
            fragment.game_clock = matches[1] if matches.present?
            fragment
          end
        end
      end
    end
  end
end
