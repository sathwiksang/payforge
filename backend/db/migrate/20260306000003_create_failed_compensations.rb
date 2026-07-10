class CreateFailedCompensations < ActiveRecord::Migration[8.0]
  def change
    create_table :failed_compensations, id: :uuid do |t|
      t.references :transaction, null: false, foreign_key: { to_table: :transactions }, type: :uuid
      t.string :step, null: false
      t.string :compensation, null: false
      t.text :error, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :failed_compensations, :status
    add_index :failed_compensations, [:transaction_id, :status]
  end
end
