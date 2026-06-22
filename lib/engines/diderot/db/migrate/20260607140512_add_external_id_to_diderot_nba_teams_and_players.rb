# frozen_string_literal: true

class AddExternalIdToDiderotNbaTeamsAndPlayers < ActiveRecord::Migration[6.1]
  def change
    %i(diderot_nba_players).each do |table|
      add_column table, :external_id, :integer
    end

    %i(
      diderot_nba_players
      diderot_nba_teams
      diderot_nba_games
      diderot_nba_game_logs
      diderot_nba_team_memberships
    ).each do |table|
      add_column table, :league_id, :integer, foreign_key: { to_table: :diderot_leagues }
    end
  end
end
