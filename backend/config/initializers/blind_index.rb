BlindIndex.master_key = Rails.application.credentials.blind_index_master_key ||
                        ENV.fetch("BLIND_INDEX_MASTER_KEY") { BlindIndex.generate_key }
