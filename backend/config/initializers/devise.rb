Devise.setup do |config|
  require "devise/orm/active_record"

  config.mailer_sender = "noreply@payforge.dev"
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth, :params_auth]
  config.stretches = Rails.env.test? ? 1 : 12
  config.reconfirmable = false
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 12..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.lock_strategy = :failed_attempts
  config.unlock_keys = [:email]
  config.unlock_strategy = :both
  config.maximum_attempts = 5
  config.unlock_in = 1.hour
  config.last_attempt_warning = true
  config.timeout_in = 30.minutes
  config.navigational_formats = []
  config.sign_out_via = :delete

  config.jwt do |jwt|
    jwt.secret = Rails.application.credentials.devise_jwt_secret_key ||
                 ENV.fetch("DEVISE_JWT_SECRET_KEY") { SecureRandom.hex(64) }
    jwt.dispatch_requests = [
      ["POST", %r{^/api/v1/auth/sign_in$}]
    ]
    jwt.revocation_requests = [
      ["DELETE", %r{^/api/v1/auth/sign_out$}]
    ]
    jwt.expiration_time = 1.hour.to_i
  end
end
