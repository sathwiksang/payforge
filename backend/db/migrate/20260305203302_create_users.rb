class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      # Devise core
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      # Devise recoverable
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      # Devise rememberable
      t.datetime :remember_created_at

      # Devise trackable
      t.integer :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip

      # Devise lockable
      t.integer :failed_attempts, default: 0, null: false
      t.string :unlock_token
      t.datetime :locked_at

      # Devise two-factor
      t.string :encrypted_otp_secret
      t.integer :consumed_timestep
      t.boolean :otp_required_for_login, default: false, null: false

      # Application fields
      t.references :merchant, type: :uuid, foreign_key: true
      t.string :role, null: false, default: "viewer"
      t.string :first_name
      t.string :last_name

      # JWT revocation (denylist strategy handled in separate table)

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :unlock_token, unique: true
    add_index :users, :role
  end
end
