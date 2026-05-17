# frozen_string_literal: true

module Diderot
  module NBA
    class Game < ApplicationRecord
      self.table_name = 'diderot_nba_games'
    end
  end
end

# == Schema Information
#
# Table name: diderot_nba_games
#
#  id                    :bigint           not null, primary key
#  away_timezone         :string
#  broadcast_network     :string
#  home_timezeone        :string
#  scheduled_at          :datetime
#  season_type           :string
#  season_year           :bigint
#  status                :string
#  venue_name            :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  away_team_id          :bigint
#  external_id           :string
#  external_reference_id :string
#  home_team_id          :bigint
#
# Indexes
#
#  index_diderot_nba_games_on_away_team_id  (away_team_id)
#  index_diderot_nba_games_on_home_team_id  (home_team_id)
#
# Foreign Keys
#
#  fk_rails_...  (away_team_id => diderot_nba_teams.id)
#  fk_rails_...  (home_team_id => diderot_nba_teams.id)
#
