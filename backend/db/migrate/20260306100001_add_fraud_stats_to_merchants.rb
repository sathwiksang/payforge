class AddFraudStatsToMerchants < ActiveRecord::Migration[8.0]
  def change
    add_column :merchants, :average_transaction_cents, :bigint, default: 0, null: false
    add_column :merchants, :transaction_count_30d, :integer, default: 0, null: false
    add_column :merchants, :chargeback_rate_90d, :decimal, precision: 5, scale: 4, default: 0.0, null: false
    add_column :merchants, :onboarded_at, :datetime
    add_column :merchants, :risk_tier, :string, default: "standard", null: false
  end
end
