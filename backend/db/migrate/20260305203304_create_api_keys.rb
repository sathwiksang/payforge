class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys, id: :uuid do |t|
      t.references :merchant, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :key_prefix, null: false, limit: 8
      t.string :key_digest, null: false
      t.string :environment, null: false, default: "test"
      t.datetime :last_used_at
      t.datetime :expires_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :api_keys, :key_digest, unique: true
    add_index :api_keys, :key_prefix
    add_index :api_keys, [:merchant_id, :environment]
  end
end
