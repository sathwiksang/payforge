class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Composite index for merchant transaction lists (ordered by created_at)
    add_index :transactions, [:merchant_id, :created_at],
              name: "idx_transactions_merchant_created",
              order: { created_at: :desc },
              algorithm: :concurrently,
              if_not_exists: true

    # Composite index for merchant + status filtering
    add_index :transactions, [:merchant_id, :status],
              name: "idx_transactions_merchant_status",
              algorithm: :concurrently,
              if_not_exists: true

    # Composite for fraud review queue: fraud_decision + fraud_score
    add_index :transactions, [:fraud_decision, :fraud_score],
              name: "idx_transactions_fraud_decision_score",
              algorithm: :concurrently,
              if_not_exists: true

    # GIN index on metadata JSONB for flexible filtering
    add_index :transactions, :metadata,
              using: :gin,
              name: "idx_transactions_metadata_gin",
              algorithm: :concurrently,
              if_not_exists: true

    # Ledger entries: account + created_at for balance queries
    add_index :ledger_entries, [:account_id, :created_at],
              name: "idx_ledger_entries_account_created",
              order: { created_at: :desc },
              algorithm: :concurrently,
              if_not_exists: true

    # Webhook delivery: event_type for filtering
    add_index :webhook_delivery_attempts, :event_type,
              name: "idx_webhook_attempts_event_type",
              algorithm: :concurrently,
              if_not_exists: true

    # Event store: composite for stream queries
    add_index :event_store_events, [:event_type, :created_at],
              name: "idx_es_events_type_created",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
