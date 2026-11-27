# frozen_string_literal: true

module Diderot
  module Routes
    module HighlighComposition
      module Services
        module PostProcessing
          class SidechainCompressionService < BaseService
            include ::Diderot::Concerns::ExternalRequestCacheable
            include ::Diderot::Concerns::CommandTools::Brew

            def self.call(*args) = new(*args).call

            def initialize(source)
              @source = source
            end

            def call
              safely_execute do
                transposable_audio_urls = Rails.application.credentials.dig(*%i(diderot post_processing sources))
                transposable_audio_files = transposable_audio_urls.entries.map(&method(:download_with_cache!))
                audio_path = transposable_audio_files.sample
                _, err, status = exec(<<-cmd.chomp,
                  ffmpeg -i #{@source} -stream_loop -1 -i #{audio_path} -filter_complex#{" "}
                  "[0:a]volume=0.15[a0];[1:a]volume=1.0[a1];[a0][a1]amix=inputs=2:duration=first[aout]"#{" "}
                  -map 0:v:0 -map "[aout]" -c:v copy -c:a aac #{@audio}"
                cmd
                                     )
                return context.fail!(errors: [err]) unless status
              ensure
                transposable_audio_files.each(&:close!)
              end
            end

            private

            def download_with_cache!((key, url))
              _, bytes = cache_stream!(url, &->(io) { HTTParty.get(url, stream_body: true) { io.write(_1) } })
              tmpfile = Tempfile.new([key, '.mp3'], binmode: true)
              cmd = "ffmpeg -y -i pipe:0 -vn -c:a libmp3lame -b:a 192k #{tmpfile.path}"
              exec(cmd, nil, stdin_data: bytes.b)
              tmpfile
            end
          end
        end
      end
    end
  end
end
