# frozen_string_literal: true

require 'tmpdir'

module Diderot
  module Providers
    module Replays
      class BasketballVideo
        def initialize(game, date, provider:)
          @game = game
          @provider = provider
        end

        def call
          # Basketball video's container naming convention is away_team_name vs home_team_name
          home_team = ::Decorators::NBA::TeamDecorator.decorate(game.home_team)
          away_team = ::Decorators::NBA::TeamDecorator.decorate(game.away_team)
          # e.g San Antonio Spurs vs Oklahoma City Thunder
          contained_text = "#{away_team.full_name} vs. #{home_team.full_name}"
          # same site contains the game url as an href attribute see example
          # <a href="/san-antonio-spurs-vs-oklahoma-city-thunder-game-1-full-game-replay-nba-playoffs-may-18-2026">San Antonio Spurs
          #  vs. Oklahoma City Thunder Game 1 - Full Game Replay - NBA Playoffs - May 18, 2026</a>
          html_content = Nokogiri::HTML(safely_open(URI.parse(configuration[:url])))
          game_path = html_content.at_xpath("//a[contains(text(), '#{contained_text}')]")&.dig('href')
          return unless game_path

          # visit the next path (append the extracted game path to the base uri) and find the exact video link for the full game
          # e.g https://basketball-video.com/san-antonio-spurs-vs-oklahoma-city-thunder-game-1-full-game-replay-nba-playoffs-may-18-2026
          html_content = Nokogiri::HTML(safely_open(URI.parse("#{configuration[:url]}#{game_path}")))
          # The button with the full game is typically the first one containing the text "Watch"
          replays_list_link = html_content.at_xpath("//a[text()='#{configuration[:full_game_link_container_text]}]")['href']
          # Visit the contained link: here's an example
          # https://guidedesgemmes.com/effets-de-la-pierre-d-emeraude-en-combien-de-jours-les-ressent-on
          # The videos themselves are iframes referencing https://ok.ru/ hyeperlinks
          html_content = Nokogiri::HTML(safely_open(URI.parse(replays_list_link)))
          # ex: <iframe allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
          # allowfullscreen="" class="yt-embed" frameborder="0" height="315"  src="//ok.ru/videoembed/14564167191212"
          # width="560" spellcheck="false"></iframe>
          iframe_src = html_content.at_css('iframe')&.[]('src')
          download_url = "#{configuration[:okru_video_base]}/#{iframe_src.split("/").last}"
          # start the download and return the file path (even with capybara and league pass )
          # invoke yt-dlp with the url
          tmpdir = Dir.mkdir(Digest::SHA256.hexdigest(game.id))
          # https://github.com/yt-dlp/yt-dlp
          unless command_exists?('yt-dlp')
            unless command_exists?('uv')
              %x(curl -LsSf https://astral.sh/uv/install.sh | sh')
            end
            system('uv tool install yt-dlp')
          end
          # this should take quite some time to complete downloading
          system("yt-dlp -P #{tmpdir} #{download_url}")
        end

        private

        attr_reader :game, :provider

        def command_exists?(cmd) = system("type #{cmd} > /dev/null 2>&1")

        def configuration
          @configuration ||= {
            url:                           'https://basketball-video.com',
            full_game_link_container_text: 'Watch',
            okru_video_base:               'https://ok.ru/video', # ex: https://ok.ru/video/14564061022892
          }
        end

        def safely_open(uri)
          url.open(&:read) if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        end
      end
    end
  end
end
