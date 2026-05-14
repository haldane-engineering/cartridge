# frozen_string_literal: true

class CreateDiderotTeams < ActiveRecord::Migration[6.1]
  def change
    create_table :diderot_teams do |t|
      t.string :name
      t.string :external_id
      t.string :market
      t.string :logo_url

      t.timestamps
    end
  end
end
