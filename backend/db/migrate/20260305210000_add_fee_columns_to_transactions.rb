class AddFeeColumnsToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :fee_cents, :integer
    add_column :transactions, :net_cents, :integer
  end
end
