require "rails_helper"

RSpec.describe ApiKeyAuthentication do
  let(:app) { ->(env) { [200, env, ["OK"]] } }
  let(:middleware) { described_class.new(app) }
  let(:merchant) { create(:merchant) }

  def make_request(path: "/api/v1/transactions", headers: {})
    env = Rack::MockRequest.env_for(path, headers)
    middleware.call(env)
  end

  it "passes through non-API requests unchanged" do
    status, env, = make_request(path: "/health")
    expect(status).to eq(200)
    expect(env["payforge.api_key"]).to be_nil
  end

  it "sets api_key in env when valid X-Api-Key provided" do
    _key, raw_key = ApiKey.generate_for(merchant: merchant, name: "test")

    status, env, = make_request(headers: { "HTTP_X_API_KEY" => raw_key })
    expect(status).to eq(200)
    expect(env["payforge.api_key"]).to be_present
    expect(env["payforge.merchant_id"]).to eq(merchant.id)
  end

  it "sets api_key when valid Bearer token with pk_ prefix provided" do
    _key, raw_key = ApiKey.generate_for(merchant: merchant, name: "test")

    status, env, = make_request(headers: { "HTTP_AUTHORIZATION" => "Bearer #{raw_key}" })
    expect(status).to eq(200)
    expect(env["payforge.api_key"]).to be_present
  end

  it "passes through with nil api_key when invalid key provided" do
    status, env, = make_request(headers: { "HTTP_X_API_KEY" => "invalid_key" })
    expect(status).to eq(200)
    expect(env["payforge.api_key"]).to be_nil
  end

  it "passes through with nil api_key when no key provided" do
    status, env, = make_request
    expect(status).to eq(200)
    expect(env["payforge.api_key"]).to be_nil
  end

  it "updates last_used_at on successful authentication" do
    key, raw_key = ApiKey.generate_for(merchant: merchant, name: "test")

    expect {
      make_request(headers: { "HTTP_X_API_KEY" => raw_key })
    }.to change { key.reload.last_used_at }
  end
end
