class AddSagaStepToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :saga_step, :integer, default: 0, null: false
    add_column :transactions, :card_token, :string
  end
end
