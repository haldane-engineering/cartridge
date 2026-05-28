# frozen_string_literal: true

module Diderot
  module Providers
    module Replays
      class StreamEast
        include Capybara::DSL
        include ::Diderot::Concerns::CommandTools::Brew

        def initialize(game, provider:)
          @game = game
          @provider = provider
          @stream_status = initial_stream_status
        end

        def call
          # [ Sidecar Setup Process ] ──> Sets up Xvfb (Virtual Display) & PulseAudio (Virtual Sound)
          # [ Capybara-Selenium ] ──────> Launches Headless Chrome inside Xvfb -> Logs in -> Fullscreens Player
          # [ Background FFmpeg ] ──────> x11grab records frame buffer directly to a compressed 30fps target
          # [ Post-Game Trim ] ─────────> Slices off dead-air in < 60 seconds -> Ready to deploy
          setup_virtual_environment
          register_selenium_driver
          # then proceed
          visit(configuration[:url])
          # streameast is loaded with ads -> so we have to switch to the actual view every time a link is clicked
          original_window = current_window
          # click the nba games category
          # <a href="/nba-streams/" class="se-mob-card" data-sport="nba">
          # <i class="fas fa-basketball-ball se-sport-fa--sport se-mob-card-icon"></i>
          # <span class="se-mob-card-label">NBA</span>
          # </a>
          click_link(href: configuration[:nba_anchor_href])
          switch_to_window(original_window)
          html_content = html_content = Nokogiri::HTML(page.body)
          # golden-state-warriors-vs-cleveland-cavaliers
          # cleveland-cavaliers-vs-golden-state-warriors
          g_links = [game.participants, game.participants.reverse].flat_map(&->(teams) {
            teams.map(&->(team) { team.full_name.downcase.tr(' ', '-') }).join('-vs-')
          })
          stream_links = g_links.map(&->(link) { html_content.at_xpath("//a[contains(href(), '#{link}')]") }).compact
          halt!(:failed_replay_capture_error) unless stream_links
          s_link_anchor = html_content.at_xpath("//a[contains(href(), '#{stream_links.first}')]")
          page.find(:xpath, s_link_anchor.path).click
          switch_to_window(original_window)
          # wait for stream to load -> remember to factor in this buffer when pruning the stream -> or generally add this
          # as a padding to the slicing start and end points
          start_stream!
          unmute_and_fullscreen_stream(original_window:)
          sleep configuration[:stream_load_buffer]
          start_screen_capture!
        ensure
          Capybara.reset_sessions!
        end

        private

        attr_reader :game, :provider

        def unmute_and_fullscreen_stream(original_window:)
          within_frame('iframe') do
            find(:xpath, "//*[contains(text(), '#{configuration[:unmute_button_text]}')]").click
          end
          sleep 1.second
          switch_to_window(original_window)
          within_frame('iframe') do
            stream_element = find('video', wait: 5)
            page.execute_script(
              "arguments[0].addEventListener('click', () => arguments[0].requestFullscreen(), { once: true });",
              stream_element,
            )
            stream_element.click
            switch_to_window(original_window)
          end
        end

        def setup_virtual_environment
          # set up virtual audo capture using pulse audio, the following command creates a virtual speaker
          # and uses pulse audio to capture the sound output from the current view context
          ENV['DISPLAY'] = ':99'
          cmd = <<~CMD
            Xvfb :99 -screen 0 1920x1080x24 &
            pulseaudio -D --exit-idle-time=-1
            pactl load-module module-null-sink sink_name=virtual_speaker
            pactl set-default-sink virtual_speaker
          CMD
          cmd.split("\n").map(&:strip).each(&->(cmnd) { shell_exec(cmnd) })
        end

        def register_selenium_driver
          Capybara.register_driver :selenium_chrome do |app|
            options = Selenium::WebDriver::Chrome::Options.new
            options.add_argument('--disable-gpu')
            options.add_argument('--no-sandbox')
            options.add_argument('--window-size=1920,1080')
            Capybara::Selenium::Driver.new(app, browser: :chrome) # headless_chrome in prod
          end
          Capybara.javascript_driver = :selenium_chrome
        end

        def configuration
          @configuration ||= {
            url:                'https://streameast.sk',
            nba_anchor_href:    '/nba-streams/',
            stream_load_buffer: 6.seconds,
            unmute_button_text: 'UNMUTE ME',
          }
        end

        def start_screen_capture!
          ffmpeg_cmd = <<~CMD.squish
            ffmpeg -f x11grab -video_size 1920x1080 -framerate 30 -i :99.0 \
            -f pulse -i virtual_speaker.monitor \
            -c:v libx264 -preset superfast -crf 22 \
            -c:a aac -b:a 128k \
            #{Digest::SHA256.hexdigest(game.id)}/source/capture.mp4
          CMD
          ffmpeg_pid = IO.popen(ffmpeg_cmd).pid
          # Periodically check for stream conclusion every 10 minutes
          loop do
            sleep 600
            if page.has_content?(configuration[:stream_ended_text])
              end_stream!
              break
            end
          end
          gracefully_shutdown_stream!(ffmpeg_pid)
        end

        def gracefully_shutdown_stream!(pid)
          Process.kill('INT', pid)
          Process.wait(pid)
        end

        def initial_stream_status = :queued
        def start_stream! = @stream_status = :started
        def end_stream! = @stream_status = :ended
        def stream_ended? = @stream_status == :eneded
      end
    end
  end
end
