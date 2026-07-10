class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions, id: :uuid do |t|
      t.references :merchant, type: :uuid, null: false, foreign_key: true
      t.string :idempotency_key, null: false
      t.string :status, null: false, default: "pending"
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "USD", limit: 3
      t.string :card_last_four, limit: 4
      t.string :card_brand, limit: 20
      t.decimal :fraud_score, precision: 5, scale: 4
      t.string :fraud_decision
      t.jsonb :metadata, null: false, default: {}
      t.jsonb :fraud_explanation
      t.string :authorization_code
      t.string :network_transaction_id
      t.datetime :authorized_at
      t.datetime :captured_at
      t.datetime :settled_at
      t.datetime :failed_at
      t.datetime :refunded_at
      t.string :failure_reason
      t.timestamps
    end

    add_index :transactions, [:merchant_id, :idempotency_key], unique: true
    add_index :transactions, :status
    add_index :transactions, :fraud_score
    add_index :transactions, :fraud_decision
    add_index :transactions, :created_at
  end
end
