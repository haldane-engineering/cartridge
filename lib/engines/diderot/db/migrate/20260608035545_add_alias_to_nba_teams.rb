# frozen_string_literal: true

class AddAliasToNbaTeams < ActiveRecord::Migration[6.1]
  def change
    add_column :diderot_nba_teams, :alias, :string
  end
end
