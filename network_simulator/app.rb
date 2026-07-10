require "sinatra/base"
require "oj"
require "securerandom"
require "yaml"

require_relative "lib/authorization"
require_relative "lib/capture"
require_relative "lib/settlement"
require_relative "lib/scenarios"
require_relative "lib/latency"

class NetworkSimulator < Sinatra::Base
  set :port, 4000
  set :bind, "0.0.0.0"

  configure do
    set :scenarios, Scenarios.load_config
    set :idempotency_store, {}
    set :authorizations, {}
  end

  before do
    content_type :json
  end

  get "/health" do
    Oj.dump({
      status: "healthy",
      service: "payment_network_simulator",
      timestamp: Time.now.utc.iso8601
    })
  end

  post "/v1/authorize" do
    payload = parse_body
    return error_response(400, "Missing required fields") unless valid_auth_request?(payload)

    idempotency_key = request.env["HTTP_IDEMPOTENCY_KEY"]
    if idempotency_key && settings.idempotency_store[idempotency_key]
      return Oj.dump(settings.idempotency_store[idempotency_key])
    end

    Latency.simulate(:authorization, settings.scenarios)

    result = Authorization.process(payload, settings.scenarios)
    settings.authorizations[result[:id]] = result if result[:status] == "approved"

    if idempotency_key
      settings.idempotency_store[idempotency_key] = result
    end

    status result[:status] == "approved" ? 200 : 402
    Oj.dump(result)
  end

  post "/v1/capture" do
    payload = parse_body
    auth_id = payload["authorization_id"]
    return error_response(400, "Missing authorization_id") unless auth_id

    auth = settings.authorizations[auth_id]
    return error_response(404, "Authorization not found") unless auth

    Latency.simulate(:capture, settings.scenarios)

    result = Capture.process(auth, payload)
    status 200
    Oj.dump(result)
  end

  post "/v1/void" do
    payload = parse_body
    auth_id = payload["authorization_id"]
    return error_response(400, "Missing authorization_id") unless auth_id

    auth = settings.authorizations.delete(auth_id)
    return error_response(404, "Authorization not found") unless auth

    Oj.dump({
      id: "void_#{SecureRandom.hex(12)}",
      authorization_id: auth_id,
      status: "voided",
      timestamp: Time.now.utc.iso8601
    })
  end

  post "/v1/refund" do
    payload = parse_body
    return error_response(400, "Missing amount") unless payload["amount"]

    Oj.dump({
      id: "ref_#{SecureRandom.hex(12)}",
      status: "approved",
      amount: payload["amount"],
      currency: payload["currency"] || "USD",
      timestamp: Time.now.utc.iso8601
    })
  end

  post "/v1/settle" do
    payload = parse_body
    transaction_ids = payload["transaction_ids"] || []
    return error_response(400, "No transactions to settle") if transaction_ids.empty?

    results = Settlement.process_batch(transaction_ids)
    Oj.dump(results)
  end

  private

  def parse_body
    body = request.body.read
    return {} if body.empty?
    Oj.load(body)
  rescue Oj::ParseError
    halt 400, Oj.dump({ error: "Invalid JSON" })
  end

  def valid_auth_request?(payload)
    payload["amount"] && payload["currency"] && payload["card_number"]
  end

  def error_response(code, message)
    halt code, Oj.dump({ error: message })
  end
end
