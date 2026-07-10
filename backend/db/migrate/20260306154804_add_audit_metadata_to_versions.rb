class AddAuditMetadataToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :versions, :actor_id, :uuid
    add_column :versions, :actor_ip, :string
    add_column :versions, :action_type, :string
    add_column :versions, :merchant_id, :uuid
    add_index :versions, :actor_id
    add_index :versions, :merchant_id
  end
end
