# frozen_string_literal: true

module Nba
  module Distributions
    module Youtube
      class GameDecorator < SimpleDecorator
        # decorates ::Diderot::Nba::Game
        delegate_all

        COPYRIGHT_DISCLAIMER = <<~str
          This video was edited to follow youtube's fair use guidelines:
          Copyright Disclaimer under Section 107 of the copyright act 1976, allowance is
          made for fair use for purposes such as criticism, comment, news reporting, scholarship, and research.
        str

        def keywords
          @keywords ||= begin
            team_parts = participants.flat_map(&->(t) { [t.market, t.name] })
            vs_parts = "#{away_team.full_name} vs #{home_team.full_name}"
            [*team_parts, vs_parts]
          end
        end

        def description
          @description ||= <<-str
              #{preamble_tags.join(", ")}

              #{full_identifier.gsub("-", " ")}.

              #{COPYRIGHT_DISCLAIMER}
          str
        end

        private

        def preamble_tags
          @preamble_tags ||= ['#NBA', *participants.map(&->(team) { "##{team.name}" })]
        end
      end
    end
  end
end
