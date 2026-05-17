# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2026_05_16_233913) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "diderot_nba_game_logs", force: :cascade do |t|
    t.string "external_id"
    t.string "status"
    t.jsonb "raw_json"
    t.bigint "game_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["game_id"], name: "index_diderot_nba_game_logs_on_game_id"
  end

  create_table "diderot_nba_games", force: :cascade do |t|
    t.string "external_id"
    t.string "external_reference_id"
    t.datetime "scheduled_at"
    t.string "status"
    t.string "home_timezeone"
    t.string "away_timezone"
    t.string "season_type"
    t.bigint "season_year"
    t.string "venue_name"
    t.string "broadcast_network"
    t.bigint "home_team_id"
    t.bigint "away_team_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["away_team_id"], name: "index_diderot_nba_games_on_away_team_id"
    t.index ["home_team_id"], name: "index_diderot_nba_games_on_home_team_id"
  end

  create_table "diderot_nba_players", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "photo_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "diderot_nba_team_memberships", force: :cascade do |t|
    t.bigint "player_id"
    t.bigint "team_id"
    t.boolean "active"
    t.string "number"
    t.string "role"
    t.string "photo_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["player_id"], name: "index_diderot_nba_team_memberships_on_player_id"
    t.index ["team_id"], name: "index_diderot_nba_team_memberships_on_team_id"
  end

  create_table "diderot_nba_teams", force: :cascade do |t|
    t.string "name"
    t.string "external_id"
    t.string "market"
    t.string "logo_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "diderot_nba_game_logs", "diderot_nba_games", column: "game_id"
  add_foreign_key "diderot_nba_games", "diderot_nba_teams", column: "away_team_id"
  add_foreign_key "diderot_nba_games", "diderot_nba_teams", column: "home_team_id"
  add_foreign_key "diderot_nba_team_memberships", "diderot_nba_players", column: "player_id"
  add_foreign_key "diderot_nba_team_memberships", "diderot_nba_teams", column: "team_id"
end
