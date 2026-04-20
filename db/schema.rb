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

ActiveRecord::Schema[8.1].define(version: 2026_04_21_120000) do
  create_table "account_balances", force: :cascade do |t|
    t.integer "account_id", null: false
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.string "balance_type", null: false
    t.datetime "created_at", null: false
    t.boolean "credit_limit_included", default: false, null: false
    t.string "currency", null: false
    t.datetime "last_change_date_time"
    t.date "reference_date"
    t.datetime "updated_at", null: false
    t.index ["account_id", "balance_type"], name: "index_account_balances_on_account_id_and_balance_type", unique: true
    t.index ["account_id"], name: "index_account_balances_on_account_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "bban"
    t.string "bic"
    t.string "cash_account_type"
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.string "iban"
    t.string "msisdn"
    t.string "name"
    t.string "owner_name"
    t.string "product"
    t.json "raw_data", default: {}, null: false
    t.string "resource_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.string "usage"
    t.index ["resource_id"], name: "index_accounts_on_resource_id", unique: true
  end

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

  create_table "ca_certificates", force: :cascade do |t|
    t.boolean "is_root", default: false
    t.integer "path_length_constraint"
  end

  create_table "certificates", force: :cascade do |t|
    t.integer "certifiable_id", null: false
    t.string "certifiable_type", null: false
    t.datetime "created_at", null: false
    t.text "csr"
    t.string "issuer_dn"
    t.integer "issuer_id"
    t.string "name"
    t.datetime "not_after"
    t.datetime "not_before"
    t.text "pem_content"
    t.text "private_key"
    t.string "public_key_hash"
    t.text "public_key_pem"
    t.string "revocation_reason"
    t.datetime "revoked_at"
    t.string "serial_number", null: false
    t.string "status", default: "pending", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["certifiable_type", "certifiable_id"], name: "index_certificates_on_certifiable_type_and_certifiable_id"
    t.index ["public_key_hash"], name: "index_certificates_on_public_key_hash"
    t.index ["status"], name: "index_certificates_on_status"
  end

  create_table "companies", force: :cascade do |t|
    t.string "address", null: false
    t.string "city", null: false
    t.string "country_code", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "official_name"
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
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.string "upstream_consent_id"
    t.index ["provider_id", "upstream_consent_id"], name: "index_consents_on_provider_upstream", unique: true
    t.index ["provider_id"], name: "index_consents_on_provider_id"
    t.check_constraint "status IN ('pending','accepted','received','valid','partiallyAuthorised','rejected','revokedByPsu','expired','terminatedByTpp')", name: "consents_status_check"
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
    t.datetime "registered_at"
    t.datetime "registration_request_sent_at"
    t.integer "representative_id", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_providers_on_code", unique: true
    t.index ["company_id"], name: "index_providers_on_company_id"
    t.index ["representative_id"], name: "index_providers_on_representative_id"
  end

  create_table "qseal_certificates", force: :cascade do |t|
    t.json "custom_attributes", default: {}
    t.integer "provider_id", null: false
    t.json "qc_statement_data", default: [], null: false
    t.string "tsp_name", null: false
    t.index ["provider_id"], name: "index_qseal_certificates_on_provider_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "account_id", null: false
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.date "booking_date"
    t.string "booking_status", null: false
    t.datetime "created_at", null: false
    t.string "creditor_iban"
    t.string "creditor_name"
    t.string "currency", null: false
    t.string "debtor_iban"
    t.string "debtor_name"
    t.string "proprietary_bank_transaction_code"
    t.json "raw_data", default: {}, null: false
    t.text "remittance_information_unstructured"
    t.string "transaction_id"
    t.datetime "updated_at", null: false
    t.date "value_date"
    t.index ["account_id", "transaction_id"], name: "index_transactions_on_account_id_and_transaction_id", unique: true, where: "transaction_id IS NOT NULL"
    t.index ["account_id"], name: "index_transactions_on_account_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "account_balances", "accounts"
  add_foreign_key "certificates", "certificates", column: "issuer_id"
  add_foreign_key "companies_users", "companies"
  add_foreign_key "companies_users", "users"
  add_foreign_key "consents", "providers"
  add_foreign_key "events", "consents"
  add_foreign_key "events", "providers"
  add_foreign_key "providers", "companies"
  add_foreign_key "providers", "users", column: "representative_id"
  add_foreign_key "qseal_certificates", "providers"
  add_foreign_key "transactions", "accounts"
end
