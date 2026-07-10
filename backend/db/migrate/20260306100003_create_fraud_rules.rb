class CreateFraudRules < ActiveRecord::Migration[8.0]
  def change
    create_table :fraud_rules, id: :uuid do |t|
      t.string :name, null: false
      t.string :rule_type, null: false # velocity, amount, round_amount, time, first_transaction
      t.string :severity, null: false, default: "medium" # low, medium, high, critical
      t.string :description
      t.jsonb :conditions, default: {}, null: false
      t.boolean :enabled, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :fraud_rules, :name, unique: true
    add_index :fraud_rules, :enabled
    add_index :fraud_rules, [:enabled, :position]
  end
end
