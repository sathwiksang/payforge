class EnableExtensions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "uuid-ossp" unless extension_enabled?("uuid-ossp")
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")
  end
end
