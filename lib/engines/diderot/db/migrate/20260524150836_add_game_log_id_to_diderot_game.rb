# frozen_string_literal: true

class AddGameLogIdToDiderotGame < ActiveRecord::Migration[6.1]
  def change
    add_column :diderot_nba_games, :game_log_id, :integer
    add_index :diderot_nba_games, :game_log_id
    add_foreign_key :diderot_nba_games, :diderot_nba_game_logs, column: :game_log_id, on_delete: :nullify
  end
end
