# frozen_string_literal: true

class CreateDiderotNbaGameLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :diderot_nba_game_logs do |t|
      t.string :external_id
      t.string :status
      t.jsonb :raw_json
      t.references :game, foreign_key: { to_table: :diderot_nba_games }

      t.timestamps
    end
  end
end
