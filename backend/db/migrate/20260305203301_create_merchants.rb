class CreateMerchants < ActiveRecord::Migration[8.1]
  def change
    create_table :merchants, id: :uuid do |t|
      t.string :name, null: false
      t.text :email_ciphertext, null: false
      t.string :email_bidx
      t.string :status, null: false, default: "active"
      t.jsonb :settings, null: false, default: {}
      t.text :webhook_url_ciphertext
      t.text :webhook_secret_ciphertext
      t.timestamps
    end

    add_index :merchants, :email_bidx, unique: true
    add_index :merchants, :status
  end
end
