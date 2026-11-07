# frozen_string_literal: true

class ChangeColumnTypeForDiderotNbaPlayers < ActiveRecord::Migration[6.1]
  def change
    change_column :diderot_nba_players, :external_id, :text
  end
end
