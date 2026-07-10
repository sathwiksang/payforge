Rails.application.config.active_record.encryption.primary_key = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY") { "0wqmzZ8sMV9DSb58yqVsYijiFu8MnnLi" }
Rails.application.config.active_record.encryption.deterministic_key = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY") { "RDygt3H75LGvDoHS1n0Aq11ZihMLIeo1" }
Rails.application.config.active_record.encryption.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT") { "6EWky3qWEmq5IyeSzvcA8taa27iCqQdy" }
