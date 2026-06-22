# frozen_string_literal: true

class AddBoxScoreToNbaGameLogs < ActiveRecord::Migration[6.1]
  def change
    add_column :diderot_nba_game_logs, :box_score, :jsonb
  end
end
