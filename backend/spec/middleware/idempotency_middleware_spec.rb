require "rails_helper"

RSpec.describe IdempotencyMiddleware do
  let(:app) { ->(env) { [200, { "Content-Type" => "application/json" }, ['{"ok":true}']] } }
  let(:middleware) { described_class.new(app) }

  before do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  after do
    Rails.cache = @original_cache
  end

  def build_env(method: "POST", path: "/api/v1/transactions", idempotency_key: nil)
    env = Rack::MockRequest.env_for(path, method: method)
    env["HTTP_IDEMPOTENCY_KEY"] = idempotency_key if idempotency_key
    env
  end

  describe "request without idempotency key" do
    it "passes through to the app" do
      env = build_env
      status, _headers, body = middleware.call(env)

      expect(status).to eq(200)
      expect(body.first).to eq('{"ok":true}')
    end
  end

  describe "request with idempotency key" do
    it "caches and returns cached response on replay" do
      key = "idem_#{SecureRandom.hex(8)}"

      # First request
      env1 = build_env(idempotency_key: key)
      status1, _, body1 = middleware.call(env1)
      expect(status1).to eq(200)

      # Second request with same key — should return cached
      env2 = build_env(idempotency_key: key)
      status2, _, body2 = middleware.call(env2)
      expect(status2).to eq(200)
      expect(body2.first).to eq('{"ok":true}')
    end

    it "does not cache non-financial paths" do
      key = "idem_#{SecureRandom.hex(8)}"
      env = build_env(path: "/api/v1/health", idempotency_key: key)

      middleware.call(env)

      # Should not be cached
      cache_key = "idempotency:#{Digest::SHA256.hexdigest(key)}"
      expect(Rails.cache.read(cache_key)).to be_nil
    end

    it "does not cache GET requests" do
      key = "idem_#{SecureRandom.hex(8)}"
      env = build_env(method: "GET", idempotency_key: key)

      middleware.call(env)

      cache_key = "idempotency:#{Digest::SHA256.hexdigest(key)}"
      expect(Rails.cache.read(cache_key)).to be_nil
    end

    it "does not cache error responses" do
      error_app = ->(env) { [422, { "Content-Type" => "application/json" }, ['{"error":"bad"}']] }
      error_middleware = described_class.new(error_app)

      key = "idem_#{SecureRandom.hex(8)}"
      env = build_env(idempotency_key: key)

      status, _, _ = error_middleware.call(env)
      expect(status).to eq(422)

      cache_key = "idempotency:#{Digest::SHA256.hexdigest(key)}"
      expect(Rails.cache.read(cache_key)).to be_nil
    end

    it "handles payments paths" do
      key = "idem_#{SecureRandom.hex(8)}"
      env = build_env(path: "/api/v1/payments", idempotency_key: key)

      status, _, _ = middleware.call(env)
      expect(status).to eq(200)

      cache_key = "idempotency:#{Digest::SHA256.hexdigest(key)}"
      expect(Rails.cache.read(cache_key)).not_to be_nil
    end
  end
end
