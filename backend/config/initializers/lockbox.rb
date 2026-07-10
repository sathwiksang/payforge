Lockbox.master_key = Rails.application.credentials.lockbox_master_key ||
                     ENV.fetch("LOCKBOX_MASTER_KEY") { Lockbox.generate_key }
