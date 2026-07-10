class CreateFraudCases < ActiveRecord::Migration[8.0]
  def change
    create_table :fraud_cases, id: :uuid do |t|
      t.references :transaction, null: false, foreign_key: true, type: :uuid
      t.references :merchant, null: false, foreign_key: true, type: :uuid
      t.references :reviewer, foreign_key: { to_table: :users }, type: :uuid

      t.string :status, null: false, default: "open"
      t.integer :priority, null: false, default: 0
      t.decimal :risk_score, precision: 5, scale: 4, null: false
      t.string :decision, null: false # pass, review, block
      t.string :model_used, null: false
      t.decimal :latency_ms, precision: 8, scale: 2
      t.jsonb :matched_rules, default: [], null: false
      t.jsonb :shap_values, default: {}, null: false
      t.jsonb :feature_vector, default: [], null: false
      t.text :notes
      t.datetime :reviewed_at
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :fraud_cases, :status
    add_index :fraud_cases, :priority
    add_index :fraud_cases, :risk_score
    add_index :fraud_cases, [:status, :priority, :risk_score], name: "idx_fraud_cases_review_queue"
  end
end
