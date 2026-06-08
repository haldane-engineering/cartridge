# frozen_string_literal: true

class AddMetadataToLeagueAndGames < ActiveRecord::Migration[6.1]
  def change
    %i(diderot_nba_teams diderot_nba_games diderot_leagues).each do |table|
      add_column table, :metadata, :jsonb
    end
  end
end
