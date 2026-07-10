class CreateWebhookDeliveryAttempts < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_delivery_attempts, id: :uuid do |t|
      t.references :merchant, null: false, foreign_key: true, type: :uuid
      t.string :event_type, null: false
      t.string :event_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.integer :response_code
      t.text :error_message
      t.integer :attempts, null: false, default: 0
      t.datetime :delivered_at

      t.timestamps
    end

    add_index :webhook_delivery_attempts, :event_id
    add_index :webhook_delivery_attempts, :status
    add_index :webhook_delivery_attempts, [:merchant_id, :status]
  end
end
