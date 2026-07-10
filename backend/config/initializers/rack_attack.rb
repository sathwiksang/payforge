class Rack::Attack
  Rack::Attack.enabled = !Rails.env.test?

  # --- Throttle Rules ---

  # General: 100 requests per minute per IP
  throttle("req/ip", limit: 100, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/health")
  end

  # Login: 5 attempts per 20 seconds by IP
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/api/v1/auth/sign_in" && req.post?
  end

  # Login: 5 attempts per minute by email
  throttle("logins/email", limit: 5, period: 1.minute) do |req|
    if req.path == "/api/v1/auth/sign_in" && req.post?
      begin
        JSON.parse(req.body.read).dig("user", "email").to_s.downcase.gsub(/\s+/, "")
      rescue JSON::ParserError
        nil
      ensure
        req.body.rewind
      end
    end
  end

  # Payment creation: 20 per minute per API key
  throttle("api/payments", limit: 20, period: 1.minute) do |req|
    if req.path.match?(%r{/api/v1/(transactions|payments)}) && req.post?
      req.env["HTTP_X_API_KEY"] || req.env["HTTP_AUTHORIZATION"]
    end
  end

  # API key: 120 requests per minute
  throttle("api/key", limit: 120, period: 1.minute) do |req|
    if req.path.start_with?("/api/v1/") && req.env["HTTP_AUTHORIZATION"].present?
      req.env["HTTP_AUTHORIZATION"]
    end
  end

  # --- Blocklist Rules ---

  # Block requests without user agent (except health checks)
  blocklist("block/bad-ua") do |req|
    req.user_agent.blank? && !req.path.start_with?("/health")
  end

  # Block SQL injection probes in query strings
  blocklist("block/sql-injection") do |req|
    if req.query_string.present?
      decoded = CGI.unescape(req.query_string)
      decoded.match?(/(\bUNION\b|\bSELECT\b.*\bFROM\b|\bDROP\b|\bINSERT\b|\bDELETE\b|--|;.*--|\/\*)/i)
    end
  end

  # --- Custom Throttled Response ---
  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    retry_after = (match_data[:period] - (now % match_data[:period])).to_i

    headers = {
      "Content-Type" => "application/json",
      "Retry-After" => retry_after.to_s,
      "X-RateLimit-Limit" => match_data[:limit].to_s,
      "X-RateLimit-Remaining" => "0"
    }

    body = { error: "Rate limit exceeded", retry_after: retry_after }.to_json
    [429, headers, [body]]
  end
end
