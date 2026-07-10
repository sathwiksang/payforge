class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, id: :uuid do |t|
      t.references :merchant, type: :uuid, foreign_key: true
      t.string :scope, null: false
      t.string :account_type, null: false
      t.string :currency, null: false, default: "USD", limit: 3
      t.integer :balance_cents, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :accounts, [:merchant_id, :scope, :account_type, :currency],
              unique: true, name: "idx_accounts_unique_type"
    add_index :accounts, :account_type
  end
end
