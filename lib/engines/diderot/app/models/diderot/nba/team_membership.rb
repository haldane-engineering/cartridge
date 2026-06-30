# frozen_string_literal: true

module Diderot
  module Nba
    class TeamMembership < ApplicationRecord
      self.table_name = 'diderot_nba_team_memberships'

      belongs_to :team, class_name: 'Diderot::NBA::Team'
      belongs_to :player, class_name: 'Diderot::NBA::Player'
    end
  end
end

# == Schema Information
#
# Table name: diderot_nba_team_memberships
#
#  id         :bigint           not null, primary key
#  active     :boolean
#  number     :string
#  photo_url  :string
#  role       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  league_id  :integer
#  player_id  :bigint
#  team_id    :bigint
#
# Indexes
#
#  index_diderot_nba_team_memberships_on_player_id  (player_id)
#  index_diderot_nba_team_memberships_on_team_id    (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (player_id => diderot_nba_players.id)
#  fk_rails_...  (team_id => diderot_nba_teams.id)
#
