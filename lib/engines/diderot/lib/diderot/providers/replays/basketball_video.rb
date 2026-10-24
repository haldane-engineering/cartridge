# frozen_string_literal: true

require 'tmpdir'
require 'open-uri'
# TODO:
# require 'capybara/rails'

module Diderot
  module Providers
    module Replays
      class BasketballVideo
        # include Capybara::DSL
        include ::Diderot::Concerns::CommandTools::Brew

        def self.call(game, **kwargs)
          new(game, **kwargs).call
        end

        def initialize(game, provider:)
          @game = game
          @provider = provider
          @current_page = 1
        end

        def call
          # Basketball video's container naming convention is away_team_name vs home_team_name
          # home_team = provider.decorators.dig(:team).decorate(game.home_team)
          # away_team = provider.decorators.dig(:team).decorate(game.away_team)
          home_team = ::Nba::TeamDecorator.decorate(game.home_team)
          away_team = ::Nba::TeamDecorator.decorate(game.away_team)
          # e.g San Antonio Spurs vs Oklahoma City Thunder
          contained_text = "#{away_team.full_name} vs #{home_team.full_name}"
          # same site contains the game url as an href attribute see example
          # <a href="/san-antonio-spurs-vs-oklahoma-city-thunder-game-1-full-game-replay-nba-playoffs-may-18-2026">San Antonio Spurs
          #  vs. Oklahoma City Thunder Game 1 - Full Game Replay - NBA Playoffs - May 18, 2026</a>
          html_content = Nokogiri::HTML(safely_open(URI.parse(configuration[:url])))
          game_path_container = recursively_extract_game_path(html_content:, contained_text:)
          return unless game_path_container

          # visit the next path (append the extracted game path to the base uri) and find the exact video link for the full game
          # e.g https://basketball-video.com/san-antonio-spurs-vs-oklahoma-city-thunder-game-1-full-game-replay-nba-playoffs-may-18-2026
          game_path = game_path_container['href']
          html_content = Nokogiri::HTML(safely_open(URI.parse("#{configuration[:url]}#{game_path}")))
          # The button with the full game is typically the first one containing the text "Watch"
          replays_link = html_content.at_xpath("//a[span[normalize-space()='#{configuration[:game_text]}']]")['href']
          # Visit the contained link: here's an example
          # https://guidedesgemmes.com/effets-de-la-pierre-d-emeraude-en-combien-de-jours-les-ressent-on
          # The videos themselves are iframes referencing https://ok.ru/ hyeperlinks
          html_content = Nokogiri::HTML(safely_open(URI.parse(replays_link)))
          # ex: <iframe allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
          # allowfullscreen="" class="yt-embed" frameborder="0" height="315"  src="//ok.ru/videoembed/14564167191212"
          # width="560" spellcheck="false"></iframe>
          iframe_src = html_content.at_css('iframe')&.[]('src')
          download_url = "#{configuration[:okru_video_base]}/#{iframe_src.split("/").last}"
          # start the download and return the file path (even with capybara and league pass )
          # invoke yt-dlp with the url
          tmpdir = Dir.mkdir(Digest::SHA256.hexdigest(game.external_id.to_s + Time.zone.now.to_s))
          # https://github.com/yt-dlp/yt-dlp
          unless command_exists?('yt-dlp')
            unless command_exists?('uv')
              %x(curl -LsSf https://astral.sh/uv/install.sh | sh')
            end
            system('uv tool install yt-dlp')
          end
          # this should take quite some time to complete downloading
          yt_dlp_flags = '--socket-timeout 60 --fragment-retries 50 --retries 10'
          system("yt-dlp #{yt_dlp_flags} -P #{tmpdir} #{download_url}")
        end

        private

        attr_reader :game, :provider, :current_page

        def command_exists?(cmd) = system("type #{cmd} > /dev/null 2>&1")

        def configuration
          @configuration ||= {
            url:                      'https://basketball-video.com',
            game_link_container_text: 'Watch',
            okru_video_base:          'https://ok.ru/video', # ex: https://ok.ru/video/14564061022892
            max_page_retries:         3,
          }
        end

        def safely_open(uri)
          uri.open(&:read) if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        end

        def recursively_extract_game_path(html_content:, contained_text:)
          game_path_container = html_content.at_xpath("//a[contains(text(), '#{contained_text}')]")
          while current_page < configuration[:max_page_retries] && !game_path_container
            @current_page += 1
            html_content = Nokogiri::HTML(safely_open(URI.parse("#{configuration[:url]}?page#{current_page}")))
            game_path_container = html_content.at_xpath("//a[contains(text(), '#{contained_text}')]")
          end
          game_path_container
        end
      end
    end
  end
end
