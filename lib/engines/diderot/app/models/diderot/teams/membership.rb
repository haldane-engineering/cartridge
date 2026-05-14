# frozen_string_literal: true

# == Schema Information
#
# Table name: diderot_team_memberships
#
#  id         :bigint           not null, primary key
#  active     :boolean
#  number     :string
#  photo_url  :string
#  role       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  player_id  :bigint
#  team_id    :bigint
#
# Indexes
#
#  index_diderot_team_memberships_on_player_id  (player_id)
#  index_diderot_team_memberships_on_team_id    (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (player_id => diderot_players.id)
#  fk_rails_...  (team_id => diderot_teams.id)
#
module Diderot
  module Teams
    class Membership < ApplicationRecord
      self.table_name = 'diderot_team_memberships'

      belongs_to :team, class_name: 'Diderot::Team'
      belongs_to :player, class_name: 'Diderot::Player'
    end
  end
end
