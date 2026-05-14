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

ActiveRecord::Schema.define(version: 2026_05_14_094913) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "diderot_players", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "photo_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "diderot_team_memberships", force: :cascade do |t|
    t.bigint "player_id"
    t.bigint "team_id"
    t.boolean "active"
    t.string "number"
    t.string "role"
    t.string "photo_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["player_id"], name: "index_diderot_team_memberships_on_player_id"
    t.index ["team_id"], name: "index_diderot_team_memberships_on_team_id"
  end

  create_table "diderot_teams", force: :cascade do |t|
    t.string "name"
    t.string "external_id"
    t.string "market"
    t.string "logo_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "diderot_team_memberships", "diderot_players", column: "player_id"
  add_foreign_key "diderot_team_memberships", "diderot_teams", column: "team_id"
end
