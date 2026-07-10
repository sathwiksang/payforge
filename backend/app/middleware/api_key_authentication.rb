class ApiKeyAuthentication
  HEADER = "HTTP_X_API_KEY"
  BEARER_PATTERN = /\ABearer\s+(.+)\z/i

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    # Only apply to API paths
    unless request.path.start_with?("/api/")
      return @app.call(env)
    end

    # Check for API key in X-Api-Key header or Bearer token
    raw_key = extract_api_key(env)

    if raw_key
      api_key = ApiKey.authenticate(raw_key)
      if api_key
        api_key.update_column(:last_used_at, Time.current)
        env["payforge.api_key"] = api_key
        env["payforge.merchant_id"] = api_key.merchant_id
      end
    end

    @app.call(env)
  end

  private

  def extract_api_key(env)
    # X-Api-Key header
    if env[HEADER].present?
      return env[HEADER]
    end

    # Bearer token that starts with pk_
    auth = env["HTTP_AUTHORIZATION"]
    if auth.present?
      match = auth.match(BEARER_PATTERN)
      if match && match[1].start_with?("pk_")
        return match[1]
      end
    end

    nil
  end
end
