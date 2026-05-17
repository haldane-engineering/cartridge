# frozen_string_literal: true

class CreateDiderotNbaGames < ActiveRecord::Migration[6.1]
  def change
    create_table :diderot_nba_games do |t|
      t.string :external_id
      t.string :external_reference_id
      t.datetime :scheduled_at
      t.string :status
      t.string :home_timezeone
      t.string :away_timezone
      t.string :season_type
      t.bigint :season_year
      t.string :venue_name
      t.string :broadcast_network
      t.references :home_team, foreign_key: { to_table: :diderot_nba_teams }
      t.references :away_team, foreign_key: { to_table: :diderot_nba_teams }

      t.timestamps
    end
  end
end
