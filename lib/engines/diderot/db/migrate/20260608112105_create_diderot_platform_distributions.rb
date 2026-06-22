# frozen_string_literal: true

class CreateDiderotPlatformDistributions < ActiveRecord::Migration[6.1]
  def change
    create_table :diderot_platform_distributions do |t|
      t.string :url
      t.string :platform_type
      t.string :resource_type
      t.string :resource_id
      t.string :status
      t.jsonb :metadata
      t.references :league, foreign_key: { to_table: :diderot_leagues }

      t.timestamps
    end
  end
end
