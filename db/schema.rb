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

ActiveRecord::Schema[8.1].define(version: 2026_04_14_120000) do
  create_table "active_admin_comments", force: :cascade do |t|
    t.integer "author_id"
    t.string "author_type"
    t.text "body"
    t.datetime "created_at", null: false
    t.string "namespace"
    t.integer "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "companies", force: :cascade do |t|
    t.string "address", null: false
    t.string "city", null: false
    t.string "country_code", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "phone_number", null: false
    t.datetime "updated_at", null: false
    t.string "zip_code", null: false
  end

  create_table "companies_users", id: false, force: :cascade do |t|
    t.integer "company_id", null: false
    t.integer "user_id", null: false
    t.index ["company_id", "user_id"], name: "index_companies_users_on_company_id_and_user_id", unique: true
    t.index ["company_id"], name: "index_companies_users_on_company_id"
    t.index ["user_id"], name: "index_companies_users_on_user_id"
  end

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
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "representative_id", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_providers_on_code", unique: true
    t.index ["company_id"], name: "index_providers_on_company_id"
    t.index ["representative_id"], name: "index_providers_on_representative_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "companies_users", "companies"
  add_foreign_key "companies_users", "users"
  add_foreign_key "consents", "providers"
  add_foreign_key "events", "consents"
  add_foreign_key "events", "providers"
  add_foreign_key "providers", "companies"
  add_foreign_key "providers", "users", column: "representative_id"
end
