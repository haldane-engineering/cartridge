# frozen_string_literal: true

class CreateDiderotLeagues < ActiveRecord::Migration[6.1]
  def change
    create_table :diderot_leagues do |t|
      t.string :name
      t.string :ticker
      t.text :logo_base64 # Yep, I know we should be storing the file instead - assume this is technical debt, to be resolved
      t.string :type, index: true

      t.timestamps
    end
  end
end
