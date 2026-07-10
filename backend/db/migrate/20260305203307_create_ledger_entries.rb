class CreateLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_entries, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :transaction, type: :uuid, foreign_key: true
      t.string :entry_type, null: false
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "USD", limit: 3
      t.string :description
      t.string :correlation_id, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :ledger_entries, :entry_type
    add_index :ledger_entries, :correlation_id
    add_index :ledger_entries, :created_at
  end
end
