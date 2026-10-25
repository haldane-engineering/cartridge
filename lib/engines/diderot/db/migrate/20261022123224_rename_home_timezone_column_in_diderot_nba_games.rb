# frozen_string_literal: true

class RenameHomeTimezoneColumnInDiderotNbaGames < ActiveRecord::Migration[6.1]
  def change
    rename_column :diderot_nba_games, :home_timezeone, :home_timezone
  end
end
