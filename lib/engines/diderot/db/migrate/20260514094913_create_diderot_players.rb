# frozen_string_literal: true

class CreateDiderotPlayers < ActiveRecord::Migration[6.1]
  def change
    create_table :diderot_players do |t|
      t.string :first_name
      t.string :last_name
      t.string :photo_url

      t.timestamps
    end

    create_table :diderot_team_memberships do |t|
      t.references :player, foreign_key: { to_table: :diderot_players }
      t.references :team, foreign_key: { to_table: :diderot_teams }
      t.boolean :active
      t.string :number
      t.string :role
      t.string :photo_url

      t.timestamps
    end
  end
end
