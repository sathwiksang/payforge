class AddIdempotencyToLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :ledger_entries, :idempotency_key, :string
    add_index :ledger_entries, :idempotency_key, unique: true, where: "idempotency_key IS NOT NULL"
  end
end
