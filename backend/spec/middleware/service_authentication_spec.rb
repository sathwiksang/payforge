require "rails_helper"

RSpec.describe ServiceAuthentication do
  let(:app) { ->(env) { [200, env, ["OK"]] } }
  let(:middleware) { described_class.new(app) }

  def make_request(path: "/internal/status", headers: {})
    env = Rack::MockRequest.env_for(path, headers)
    middleware.call(env)
  end

  it "passes through non-internal requests" do
    status, _headers, = make_request(path: "/api/v1/transactions")
    expect(status).to eq(200)
  end

  it "rejects internal requests without service key" do
    status, _headers, body = make_request(path: "/internal/status")
    expect(status).to eq(401)
    expect(JSON.parse(body.first)["error"]).to eq("Invalid service key")
  end

  it "rejects internal requests with wrong service key" do
    status, _headers, = make_request(
      path: "/internal/status",
      headers: { "HTTP_X_SERVICE_KEY" => "wrong_key" }
    )
    expect(status).to eq(401)
  end

  it "allows internal requests with valid service key" do
    key = Rails.application.credentials.service_api_key ||
          ENV.fetch("SERVICE_API_KEY", "dev_service_key")

    status, env, = make_request(
      path: "/internal/status",
      headers: { "HTTP_X_SERVICE_KEY" => key }
    )
    expect(status).to eq(200)
    expect(env["payforge.service_authenticated"]).to be true
  end
end
