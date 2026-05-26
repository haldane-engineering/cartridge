# frozen_string_literal: true

module Diderot
  module Routes
    module HighlightComposition
      module Stops
        class ReplayRecomposition < ::Diderot::Routes::ApplicableStop
          include Diderot::Concerns::CommandTools::Python

          def call
            logs = provider.game_log_class.where(game_id: state_get(:downloaded_game_ids))
            composed_game_ids = state_get(:composed_game_ids) || []
            composable_game_ids = logs.map(&:game_id) - composed_game_ids
            # hash to get the folder when the source video is stored
            video_paths = composable_game_ids.map(&->(log) { Digest::SHA256.hexdigest(log.game_id) })
            composable_game_ids.zip(video_paths).each do |(game_id, dir_path)|
              # I know - there's a repetition here, optimize after completion
              # game_log = provider.game_log_class.find_by(game_id: game_id)
              source_file = File.expand_path(Dir.glob(File.join(dir_path, '*')).select { |f| File.file?(f) }.first)
              # preselect the events: the preselection should return a list of Fragment objects
              # for nba highlights, I imagine we add a padding: 10 seconds after the previous event.
              # and 5 seconds into the next. These numbers should be configurable.
              # The current implementation naively adds 5 seconds pre and 3 seconds post event, which might work for now
              # but to make the highlights more fleshy, I imagine we want to change this
              chunks_dir = FileUtils.mkdir_p("#{dir_path}/fragments")
              game_logs = JSON.parse(provider.game_log_class.find_by(game_id: game_id))
              # see notes on the various options here
              # https://www.baeldung.com/linux/ffmpeg-cutting-videos
              # https://medium.com/@taylorjdawson/splitting-a-video-with-ffmpeg-the-great-mystical-magical-video-tool-%EF%B8%8F-1b31385221bd
              fragments = provider.generate_highlight_fragments(game_logs, Fragment).each do |fragment|
                output, _, status = py_exec(
                  <<~cmd,
                    ffmpeg -i #{source_file} -ss #{fragment.start} -t #{fragment.end} \
                     -map 0 -c:v libx264 -b:v 3M -c:a aac -ar 44100 -ac 2 -crf 22 -f segment \
                    -async 1 #{File.expand_path(chunks_dir)}/#{fragment.title.underscore}.mp4
                  cmd
                )
                fragment.set(success: status.success?, output:)
              end
              manifest_path = "#{dir_path}/manifest.txt"
              manifest_txt = fragments.filter(&:success).reduce('', &->(sum, fragment, index) {
                sum + "#{index.zero? ? "" : "\n"} file #{chunks_dir}/#{fragment.title.underscore}.mp4"
              })
              m
              File.write(manifest_path, manifest_txt)
              f_path = "#{dir_path}/#{game.full_identifier}"
              output, _, status = py_exec("fmpeg -f concat -safe 0 -i #{manifest_path} -map 0 -c copy #{f_path}.mp4")
              # TODO: Include error propagation
              halt!(:fragment_composition_error, output) unless status
            end
          end

          Fragment = Struct.new(*%i(title start end output success), keyword_init: true) do
            def set(**attributes)
              attributes.entries { |(k, v)| send(:"#{k}=", v) }
              self
            end
          end
        end
      end
    end
  end
end
