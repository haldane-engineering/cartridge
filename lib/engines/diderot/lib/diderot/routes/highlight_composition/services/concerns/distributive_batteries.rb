# frozen_string_literal: true

module Diderot
  module Routes
    module HighlighComposition
      module Services
        module Concerns
          module DistributiveBatteries
            module FractionalComposition
              include Diderot::Concerns::CommandTools::Python

              # @param [Array<::ReplayCompositionService::Fragment>] fragments list of fragments for the video
              # @param [::Diderot::Providers::Base] provider - standard provider
              def compose_fractally!(fragments, **options)
                # Get the total number of videos -> find the number of fractions for the provider
                # split the list of fragments into the quotient of (total_no_of_videos / fraction_count)
                # create a fractions folder, it should contain fraction_count number of folders.
                # at the end of the partitioning -> we should have the folder containing the manifest.txt
                # list of relevant fragments and an out.mp4 (which is the composed video).
                provider, directory_path, game = options.values_at(*%i(provider directory_path game))
                FileUtils.mkdir_p("#{directory_path}/fractions")
                quotient = (fragments.size / provider.game_clock_attributes[:fraction_count]).round

                # naive implementation to split evenly without game clock integrity - but in this context
                # I'd argue that the oversight is trivial since we end up distributing a continuous stream.-
                fragments.each_slice(quotient).map.with_index do |fragments, index|
                  group_directory = "#{directory_path}/fractions/#{index + 1}"
                  FileUtils.mkdirp(group_directory)
                  manifest_path = write_fragments_manifest!(group_directory, fragments)

                  output_directory = "#{group_directory}/dest"
                  FileUtils.mkdir_p(output_directory)
                  output_path = "#{output_directory}/#{game.full_identifier}"
                  _, err, status = py_exec("ffmpeg -f concat -safe 0 -i #{manifest_path} -map 0 -c copy '#{output_path}.mp4'")
                  raise err unless status.success?

                  PostProcessing::SidechainCompressionService.call(output_path) if apply_sidechain_compression?(options)
                  output_path
                end
              end

              private

              def write_fragments_manifest!(directory, fragments)
                manifest_path = "#{directory}/manifest.txt"
                manifest_txt = fragments.filter(&:success?).each_with_index.reduce('', &->(sum, (fragment, index)) {
                  sum += "#{index.zero? ? "" : "\n"} file #{directory}/#{fragment.slug}.mp4"
                  sum
                })
                File.write(manifest_path, manifest_txt)
                manifest_path
              end

              def apply_sidechain_compression?(options) = options.fetch(:apply_sidechain_compression, false)
            end

            module FractionalDistribution
              def distribute_fractions!(channel)
              end
            end
          end
        end
      end
    end
  end
end
