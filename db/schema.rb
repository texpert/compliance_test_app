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

ActiveRecord::Schema[8.1].define(version: 2026_04_10_213000) do
  create_table "consents", force: :cascade do |t|
    t.text "callback_error"
    t.json "callback_params", default: {}, null: false
    t.datetime "callback_received_at"
    t.datetime "created_at", null: false
    t.integer "provider_id", null: false
    t.string "status", default: "received", null: false
    t.datetime "updated_at", null: false
    t.string "upstream_consent_id"
    t.index ["provider_id", "upstream_consent_id"], name: "index_consents_on_provider_upstream", unique: true
    t.index ["provider_id"], name: "index_consents_on_provider_id"
    t.check_constraint "status IN ('accepted','received','valid','partiallyAuthorised','rejected','revokedByPsu','expired','terminatedByTpp')", name: "consents_status_check"
  end

  create_table "events", force: :cascade do |t|
    t.integer "consent_id"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.datetime "occurred_at", null: false
    t.integer "provider_id"
    t.json "request_body", default: {}, null: false
    t.json "request_headers", default: {}, null: false
    t.json "response_body", default: {}, null: false
    t.json "response_headers", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["consent_id"], name: "index_events_on_consent_id"
    t.index ["event_type"], name: "index_events_on_event_type"
    t.index ["occurred_at"], name: "index_events_on_occurred_at"
    t.index ["provider_id"], name: "index_events_on_provider_id"
  end

  create_table "providers", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_providers_on_code", unique: true
  end

  add_foreign_key "consents", "providers"
  add_foreign_key "events", "consents"
  add_foreign_key "events", "providers"
end
