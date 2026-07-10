class AddCardLastFourIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :transactions, [:card_last_four, :created_at],
              name: "idx_transactions_card_created",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
