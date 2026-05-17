# frozen_string_literal: true

module Diderot
  module NBA
    class GameLog < ApplicationRecord
      self.table_name = 'diderot_nba_game_logs'
    end
  end
end

# == Schema Information
#
# Table name: diderot_nba_game_logs
#
#  id          :bigint           not null, primary key
#  raw_json    :jsonb
#  status      :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  external_id :string
#  game_id     :bigint
#
# Indexes
#
#  index_diderot_nba_game_logs_on_game_id  (game_id)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => diderot_nba_games.id)
#
