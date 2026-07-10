SecureHeaders::Configuration.default do |config|
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "0" # Modern browsers don't need this; can cause issues
  config.x_download_options = "noopen"
  config.x_permitted_cross_domain_policies = "none"
  config.referrer_policy = %w[strict-origin-when-cross-origin]

  config.hsts = "max-age=631138519; includeSubDomains; preload"

  config.csp = {
    default_src: %w['none'],
    script_src: %w['self'],
    style_src: %w['self' 'unsafe-inline'],
    img_src: %w['self' data:],
    font_src: %w['self'],
    connect_src: %w['self' wss:], # WebSocket for ActionCable
    base_uri: %w['self'],
    form_action: %w['self'],
    frame_ancestors: %w['none'],
    upgrade_insecure_requests: !Rails.env.development?
  }
end
