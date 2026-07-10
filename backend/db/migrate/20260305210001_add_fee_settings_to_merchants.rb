class AddFeeSettingsToMerchants < ActiveRecord::Migration[8.1]
  def change
    add_column :merchants, :fee_percentage, :decimal, precision: 5, scale: 2, null: false, default: 2.9
    add_column :merchants, :fee_fixed_cents, :integer, null: false, default: 30
  end
end
