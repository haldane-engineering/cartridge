# frozen_string_literal: true

module Diderot
  module Routes
    module HighlightComposition
      module Services
        class GameLogParser < BaseService
          FRAGMENT_KEYS = %i(game_clock real_video_time quarter)
          BEGIN_FRAGMENT_IDENTIFIER = 'frame:'
          GAME_CLOCK_IDENTIFIER = 'lavfi.ocr.text'

          def self.call(**kwargs) = new(**kwargs).call

          def initialize(game:, provider:)
            @game = game
            @provider = provider
            @fragments = []
          end

          def call
            safely_execute do
              directory_path = Rails.root.join(Digest::SHA256.hexdigest(@game.external_id))
              File.readlines("#{directory_path}/ocr.log", chomp: true).each.with_index do |line|
                if line.starts_with?(BEGIN_FRAGMENT_IDENTIFIER)
                  @fragment = assign_video_time!(line, GameLogFragment.new)
                elsif line.starts_with?(GAME_CLOCK_IDENTIFIER)
                  fragment = assign_game_clock!(line, @fragment)
                  @fragments.push(fragment) if fragment.complete?
                end
              end
              context.succeed(group_fragments_using_provider!(@fragments))
            end
          end

          GameLogFragment = Struct.new(*FRAGMENT_KEYS, keyword_init: true) do
            def complete? = game_clock && real_video_time
          end

          private

          def group_fragments_using_provider!(fragments)
            case @provider.game_clock_attributes[:type]
            # relevant for games like soccer when the time between each half is continuous i.e. the 2nd half starts at 45:00
            # and is an increasing game counter not decreasing, as we have in the NBA.
            when :continuous then fragments
            when :fractional then partition_fragments_into_fractions!(fragments)
            else fragments
            end
          end

          def partition_fragments_into_fractions!(fragments)
            # Assume that the events in the log are equally distributed across each fraction
            # there could potentially more accurate ways to assert this but I do not think the gains are worthwhile enough to
            # investigate - but POSSIBLE improvement here.
            fraction_slice = (fragments.size / @provider.game_clock_attributes[:fraction_count]).to_i
            fragments.each_slice(fraction_slice).to_a
          end

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
