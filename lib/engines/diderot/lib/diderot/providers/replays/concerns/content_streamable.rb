# frozen_string_literal: true

require 'capybara/dsl'
require 'selenium-webdriver'

module Diderot
  module Providers
    module Replays
      module Concerns
        module ContentStreamable
          include Capybara::DSL
          include ::Diderot::Concerns::CommandTools::Brew

          def self.call(game, **opts) = new(game, **opts).call

          def initialize(game, provider: nil)
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
            sleep 1.5
            click_link(href: configuration[:nba_anchor_href], match: :first)
            # switch_to_window(original_window)
            sleep 1.5
            html_content = html_content = Nokogiri::HTML(page.body)
            # golden-state-warriors-vs-cleveland-cavaliers
            # cleveland-cavaliers-vs-golden-state-warriors
            g_links = [game.participants, game.participants.reverse].flat_map(&->(teams) {
              teams.map(&->(team) {
                team = ::Nba::TeamDecorator.decorate(team)
                team.full_name.downcase.tr(' ', '-')
              }).join('-vs-')
            })
            stream_links = g_links.map(&->(link) {
              html_content.at_xpath("//a[contains(@href, '#{link}')]")
            }).compact
            halt!(:failed_replay_capture_error) if stream_links.empty?
            page.find(:xpath, stream_links.first.path).click
            switch_to_window(original_window)
            # wait for stream to load -> remember to factor in this buffer when pruning the stream -> or generally add this
            # as a padding to the slicing start and end points
            start_stream!
            unmute_and_fullscreen_stream(original_window:)
            sleep configuration[:stream_load_buffer]
            start_screen_capture!
          ensure
            teardown_browser!
            stop_virtual_display!
          end

          private

          attr_reader :game, :provider

          # def unmute_and_fullscreen_stream(original_window:)
          #   # within_frame('iframe') do
          #   #   find(:xpath, "//*[contains(text(), '#{configuration[:unmute_button_text]}')]").click
          #   # end
          #   # sleep 1.second
          #   # switch_to_window(original_window)
          #   # within_frame('iframe') do
          #   #   stream_element = find('video', wait: 5)
          #   #   page.execute_script(
          #   #     "arguments[0].addEventListener('click', () => arguments[0].requestFullscreen(), { once: true });",
          #   #     stream_element,
          #   #   )
          #   #   stream_element.click
          #   #   switch_to_window(original_window)
          #   # end
          #   within_frame(find('iframe[src*="crack-nba"]', wait: 15)) do
          #     page.execute_script(<<~JS)
          #       // Remove known ad click-jacker IDs
          #       const overlay = document.getElementById('dontfoid');
          #       if (overlay) overlay.remove();
          #       // Sweep and destroy any other massive transparent fixed overlays
          #       document.querySelectorAll('div').forEach(el => {
          #         const style = window.getComputedStyle(el);
          #         if (style.position === 'fixed' && parseInt(style.zIndex) > 1000000) {
          #           el.remove();
          #         }
          #       });
          #     JS
          #     if page.has_css?('#bigPlay', visible: true)
          #       find('#bigPlay').click
          #     else
          #       find('#playBtn', wait: 5).click
          #     end

          #     page.execute_script(<<~JS)
          #       const video = document.getElementById('video');
          #       if (video) {
          #         video.muted = false;
          #         video.volume = 1.0;
          #       }
          #     JS
          #     find('#fsBtn', wait: 5).click
          #   end
          #   # Switch back to the main window context after interaction
          #   switch_to_window(original_window)
          #   sleep 1.second
          # end
          def unmute_and_fullscreen_stream(original_window:)
            # 1. Kill window.open at the browser context level for ALL frames
            page.driver.browser.execute_cdp(
              'Page.addScriptToEvaluateOnNewDocument',
              source: 'window.open = function() { return null; };',
            )

            iframe_element = find('iframe[src*="crack-nba"]', wait: 15)

            # 2. Inject popup destruction directly into the iframe right now
            within_frame(iframe_element) do
              page.execute_script(<<~JS)
                window.open = function() { return null; };
                document.querySelectorAll('a[target="_blank"]').forEach(a => a.removeAttribute('target'));
              JS
            end

            # 3. Perform clicks cleanly without any popups opening
            max_attempts = 15
            attempts = 0

            loop do
              break if attempts >= max_attempts

              attempts += 1

              within_frame(iframe_element) do
                is_playing = page.evaluate_script(<<~JS)
                  (function() {
                    var v = document.getElementById('video');
                    return v && !v.paused;
                  })()
                JS
                break if is_playing

                if page.has_css?('#bigPlay', visible: true)
                  play_el = find('#bigPlay')
                  begin
                    play_el.click
                  rescue
                    page.driver.browser.action.click(play_el.native).perform
                  end
                elsif page.has_css?('#playBtn', visible: true)
                  play_el = find('#playBtn')
                  begin
                    play_el.click
                  rescue
                    page.driver.browser.action.click(play_el.native).perform
                  end
                end
              end

              sleep 0.8
            end

            # 4. Unmute and fullscreen
            within_frame(iframe_element) do
              page.execute_script(<<~JS)
                (function() {
                  var video = document.getElementById('video');
                  if (video) {
                    video.muted = false;
                    video.volume = 1.0;
                  }
                })();
              JS

              fs_btn = find('#fsBtn', wait: 5)
              begin
                fs_btn.click
              rescue
                page.driver.browser.action.click(fs_btn.native).perform
              end
            end

            switch_to_window(original_window)
            sleep 1.second
          end

          def setup_virtual_environment
            # set up virtual audo capture using pulse audio, the following command creates a virtual speaker
            # and uses pulse audio to capture the sound output from the current view context
            ENV['DISPLAY'] = ':99'
            start_virtual_display!
            cmd = <<~CMD
              pulseaudio -D --exit-idle-time=-1
              pactl load-module module-null-sink sink_name=virtual_speaker
              pactl set-default-sink virtual_speaker
            CMD
            cmd.split("\n").map(&:strip).each(&->(cmnd) { exec(cmnd) })
          end

          def start_virtual_display!
            exec(':', 'Xvfb')
            _, _, _, wait_thread = exec(
              'Xvfb :99 -screen 0 1920x1080x24',
              nil,
              spawn: true,
              install_with: 'brew install --cask xquartz',
            )
            @xvfb_pid = wait_thread.pid
            Process.detach(@xvfb_pid)
          end

          def stop_virtual_display!
            return unless @xvfb_pid

            Process.kill('TERM', @xvfb_pid)
          rescue Errno::ESRCH
            nil
          end

          def register_selenium_driver
            Capybara.register_driver :selenium_chrome do |app|
              options = Selenium::WebDriver::Chrome::Options.new
              options.add_argument('--disable-gpu')
              options.add_argument('--no-sandbox')
              options.add_argument('--window-size=1920,1080')
              # Hide the "Chrome is being controlled by automated software" banner
              options.add_preference('profile.default_content_setting_values.popups', 2)
              options.add_argument('--disable-blink-features=AutomationControlled')
              options.exclude_switches
              options.add_preference(:use_automation_extension, false)
              options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
              Capybara::Selenium::Driver.new(app, browser: :chrome, options:) # headless_chrome in prod
            end
            Capybara.default_driver = :selenium_chrome
            Capybara.current_driver = :selenium_chrome
            Capybara.run_server = false
          end

          def configuration
            raise NotImplementedError
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

          def teardown_browser!
            Capybara.current_session.driver.quit
          rescue StandardError => e
            Rails.logger.warn("[Streameast] browser teardown failed: #{e.class}: #{e.message}")
          end

          def initial_stream_status = :queued
          def start_stream! = @stream_status = :started
          def end_stream! = @stream_status = :ended
          def stream_ended? = @stream_status == :ended
        end
      end
    end
  end
end
