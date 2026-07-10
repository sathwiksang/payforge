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

ActiveRecord::Schema[8.1].define(version: 2026_03_07_062239) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "uuid-ossp"
  enable_extension "vector"

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "account_type", null: false
    t.boolean "active", default: true, null: false
    t.integer "balance_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "USD", null: false
    t.uuid "merchant_id"
    t.string "scope", null: false
    t.datetime "updated_at", null: false
    t.index ["account_type"], name: "index_accounts_on_account_type"
    t.index ["merchant_id", "scope", "account_type", "currency"], name: "idx_accounts_unique_type", unique: true
    t.index ["merchant_id"], name: "index_accounts_on_merchant_id"
  end

  create_table "api_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "environment", default: "test", null: false
    t.datetime "expires_at"
    t.string "key_digest", null: false
    t.string "key_prefix", limit: 8, null: false
    t.datetime "last_used_at"
    t.uuid "merchant_id", null: false
    t.string "name", null: false
    t.datetime "revoked_at"
    t.datetime "updated_at", null: false
    t.index ["key_digest"], name: "index_api_keys_on_key_digest", unique: true
    t.index ["key_prefix"], name: "index_api_keys_on_key_prefix"
    t.index ["merchant_id", "environment"], name: "index_api_keys_on_merchant_id_and_environment"
    t.index ["merchant_id"], name: "index_api_keys_on_merchant_id"
  end

  create_table "event_store_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.binary "data", null: false
    t.uuid "event_id", null: false
    t.string "event_type", null: false
    t.binary "metadata"
    t.datetime "valid_at"
    t.index ["created_at"], name: "index_event_store_events_on_created_at"
    t.index ["event_id"], name: "index_event_store_events_on_event_id", unique: true
    t.index ["event_type", "created_at"], name: "idx_es_events_type_created"
    t.index ["event_type"], name: "index_event_store_events_on_event_type"
    t.index ["valid_at"], name: "index_event_store_events_on_valid_at"
  end

  create_table "event_store_events_in_streams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "event_id", null: false
    t.integer "position"
    t.string "stream", null: false
    t.index ["created_at"], name: "index_event_store_events_in_streams_on_created_at"
    t.index ["event_id"], name: "index_event_store_events_in_streams_on_event_id"
    t.index ["stream", "event_id"], name: "index_event_store_events_in_streams_on_stream_and_event_id", unique: true
    t.index ["stream", "position"], name: "index_event_store_events_in_streams_on_stream_and_position", unique: true
  end

  create_table "failed_compensations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "compensation", null: false
    t.datetime "created_at", null: false
    t.text "error", null: false
    t.datetime "resolved_at"
    t.string "status", default: "pending", null: false
    t.string "step", null: false
    t.uuid "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_failed_compensations_on_status"
    t.index ["transaction_id", "status"], name: "index_failed_compensations_on_transaction_id_and_status"
    t.index ["transaction_id"], name: "index_failed_compensations_on_transaction_id"
  end

  create_table "fraud_cases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "decision", null: false
    t.jsonb "feature_vector", default: [], null: false
    t.decimal "latency_ms", precision: 8, scale: 2
    t.jsonb "matched_rules", default: [], null: false
    t.uuid "merchant_id", null: false
    t.string "model_used", null: false
    t.text "notes"
    t.integer "priority", default: 0, null: false
    t.datetime "resolved_at"
    t.datetime "reviewed_at"
    t.uuid "reviewer_id"
    t.decimal "risk_score", precision: 5, scale: 4, null: false
    t.jsonb "shap_values", default: {}, null: false
    t.string "status", default: "open", null: false
    t.uuid "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["merchant_id"], name: "index_fraud_cases_on_merchant_id"
    t.index ["priority"], name: "index_fraud_cases_on_priority"
    t.index ["reviewer_id"], name: "index_fraud_cases_on_reviewer_id"
    t.index ["risk_score"], name: "index_fraud_cases_on_risk_score"
    t.index ["status", "priority", "risk_score"], name: "idx_fraud_cases_review_queue"
    t.index ["status"], name: "index_fraud_cases_on_status"
    t.index ["transaction_id"], name: "index_fraud_cases_on_transaction_id"
  end

  create_table "fraud_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "conditions", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.boolean "enabled", default: true, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "rule_type", null: false
    t.string "severity", default: "medium", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled", "position"], name: "index_fraud_rules_on_enabled_and_position"
    t.index ["enabled"], name: "index_fraud_rules_on_enabled"
    t.index ["name"], name: "index_fraud_rules_on_name", unique: true
  end

  create_table "jwt_denylist", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.index ["jti"], name: "index_jwt_denylist_on_jti", unique: true
  end

  create_table "ledger_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.integer "amount_cents", null: false
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "USD", null: false
    t.string "description"
    t.string "entry_type", null: false
    t.string "idempotency_key"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "transaction_id"
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "idx_ledger_entries_account_created", order: { created_at: :desc }
    t.index ["account_id"], name: "index_ledger_entries_on_account_id"
    t.index ["correlation_id"], name: "index_ledger_entries_on_correlation_id"
    t.index ["created_at"], name: "index_ledger_entries_on_created_at"
    t.index ["entry_type"], name: "index_ledger_entries_on_entry_type"
    t.index ["idempotency_key"], name: "index_ledger_entries_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["transaction_id"], name: "index_ledger_entries_on_transaction_id"
  end

  create_table "merchants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "average_transaction_cents", default: 0, null: false
    t.decimal "chargeback_rate_90d", precision: 5, scale: 4, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "email_bidx"
    t.text "email_ciphertext", null: false
    t.integer "fee_fixed_cents", default: 30, null: false
    t.decimal "fee_percentage", precision: 5, scale: 2, default: "2.9", null: false
    t.string "name", null: false
    t.datetime "onboarded_at"
    t.string "risk_tier", default: "standard", null: false
    t.jsonb "settings", default: {}, null: false
    t.string "status", default: "active", null: false
    t.integer "transaction_count_30d", default: 0, null: false
    t.datetime "updated_at", null: false
    t.text "webhook_secret_ciphertext"
    t.text "webhook_url_ciphertext"
    t.index ["email_bidx"], name: "index_merchants_on_email_bidx", unique: true
    t.index ["status"], name: "index_merchants_on_status"
  end

  create_table "transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.string "authorization_code"
    t.datetime "authorized_at"
    t.datetime "captured_at"
    t.string "card_brand", limit: 20
    t.string "card_last_four", limit: 4
    t.string "card_token"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "USD", null: false
    t.datetime "failed_at"
    t.string "failure_reason"
    t.integer "fee_cents"
    t.string "fraud_decision"
    t.jsonb "fraud_explanation"
    t.decimal "fraud_score", precision: 5, scale: 4
    t.string "idempotency_key", null: false
    t.uuid "merchant_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.integer "net_cents"
    t.string "network_transaction_id"
    t.datetime "refunded_at"
    t.integer "saga_step", default: 0, null: false
    t.datetime "settled_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["card_last_four", "created_at"], name: "idx_transactions_card_created"
    t.index ["created_at"], name: "index_transactions_on_created_at"
    t.index ["fraud_decision", "fraud_score"], name: "idx_transactions_fraud_decision_score"
    t.index ["fraud_decision"], name: "index_transactions_on_fraud_decision"
    t.index ["fraud_score"], name: "index_transactions_on_fraud_score"
    t.index ["merchant_id", "created_at"], name: "idx_transactions_merchant_created", order: { created_at: :desc }
    t.index ["merchant_id", "idempotency_key"], name: "index_transactions_on_merchant_id_and_idempotency_key", unique: true
    t.index ["merchant_id", "status"], name: "idx_transactions_merchant_status"
    t.index ["merchant_id"], name: "index_transactions_on_merchant_id"
    t.index ["metadata"], name: "idx_transactions_metadata_gin", using: :gin
    t.index ["status"], name: "index_transactions_on_status"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "consumed_timestep"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_otp_secret"
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.uuid "merchant_id"
    t.boolean "otp_required_for_login", default: false, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "viewer", null: false
    t.integer "sign_in_count", default: 0, null: false
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["merchant_id"], name: "index_users_on_merchant_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "action_type"
    t.uuid "actor_id"
    t.string "actor_ip"
    t.datetime "created_at"
    t.string "event", null: false
    t.string "item_id", null: false
    t.string "item_type", null: false
    t.uuid "merchant_id"
    t.jsonb "object"
    t.jsonb "object_changes"
    t.string "whodunnit"
    t.index ["actor_id"], name: "index_versions_on_actor_id"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["merchant_id"], name: "index_versions_on_merchant_id"
  end

  create_table "webhook_delivery_attempts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.text "error_message"
    t.string "event_id", null: false
    t.string "event_type", null: false
    t.uuid "merchant_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.integer "response_code"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_webhook_delivery_attempts_on_event_id"
    t.index ["event_type"], name: "idx_webhook_attempts_event_type"
    t.index ["merchant_id", "status"], name: "index_webhook_delivery_attempts_on_merchant_id_and_status"
    t.index ["merchant_id"], name: "index_webhook_delivery_attempts_on_merchant_id"
    t.index ["status"], name: "index_webhook_delivery_attempts_on_status"
  end

  add_foreign_key "accounts", "merchants"
  add_foreign_key "api_keys", "merchants"
  add_foreign_key "event_store_events_in_streams", "event_store_events", column: "event_id", primary_key: "event_id"
  add_foreign_key "failed_compensations", "transactions"
  add_foreign_key "fraud_cases", "merchants"
  add_foreign_key "fraud_cases", "transactions"
  add_foreign_key "fraud_cases", "users", column: "reviewer_id"
  add_foreign_key "ledger_entries", "accounts"
  add_foreign_key "ledger_entries", "transactions"
  add_foreign_key "transactions", "merchants"
  add_foreign_key "users", "merchants"
  add_foreign_key "webhook_delivery_attempts", "merchants"
end
