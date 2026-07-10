class IdempotencyMiddleware
  IDEMPOTENT_METHODS = %w[POST PUT PATCH].freeze
  CACHE_TTL = 24.hours
  FINANCIAL_PATHS = %w[/api/v1/transactions /api/v1/payments].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    idempotency_key = request.get_header("HTTP_IDEMPOTENCY_KEY")
    return @app.call(env) unless idempotent_request?(request, idempotency_key)

    cache_key = "idempotency:#{Digest::SHA256.hexdigest(idempotency_key)}"

    cached = Rails.cache.read(cache_key)
    if cached
      return [cached[:status], cached[:headers], [cached[:body]]]
    end

    status, headers, body = @app.call(env)

    if (200..299).cover?(status)
      response_body = extract_body(body)
      Rails.cache.write(cache_key, {
        status: status,
        headers: headers.to_h,
        body: response_body
      }, expires_in: CACHE_TTL)
    end

    [status, headers, body]
  end

  private

  def idempotent_request?(request, key)
    key.present? &&
      IDEMPOTENT_METHODS.include?(request.request_method) &&
      financial_path?(request.path)
  end

  def financial_path?(path)
    FINANCIAL_PATHS.any? { |fp| path.start_with?(fp) }
  end

  def extract_body(body)
    if body.respond_to?(:body)
      body.body
    elsif body.respond_to?(:each)
      parts = []
      body.each { |part| parts << part }
      parts.join
    else
      body.to_s
    end
  end
end
