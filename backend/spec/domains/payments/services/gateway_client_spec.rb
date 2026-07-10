require "rails_helper"

RSpec.describe Payments::Services::GatewayClient do
  let(:data_store) { Stoplight::DataStore::Memory.new }
  let(:client) { described_class.new(base_url: "http://localhost:4200", data_store: data_store) }

  describe "#authorize" do
    let(:params) do
      {
        amount_cents: 5000,
        currency: "USD",
        card_token: "4242424242424242",
        merchant_id: SecureRandom.uuid,
        idempotency_key: "idem_#{SecureRandom.hex(8)}"
      }
    end

    context "when network simulator is available" do
      it "returns a GatewayResponse" do
        stub_request(:post, "http://localhost:4200/v1/authorize")
          .to_return(
            status: 200,
            body: {
              id: "auth_abc123",
              status: "approved",
              authorization_code: "AUTH001",
              response_code: "00"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        response = client.authorize(**params)

        expect(response).to be_a(Payments::Services::GatewayResponse)
        expect(response.success?).to be true
        expect(response.authorization_code).to eq("AUTH001")
      end
    end

    context "when authorization is declined" do
      it "returns a failed response with decline reason" do
        stub_request(:post, "http://localhost:4200/v1/authorize")
          .to_return(
            status: 402,
            body: {
              id: "auth_dec456",
              status: "declined",
              decline_reason: "insufficient_funds",
              response_code: "51"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        response = client.authorize(**params)

        expect(response.success?).to be false
        expect(response.decline_reason).to eq("insufficient_funds")
      end
    end

    context "when network times out" do
      it "returns a failure response" do
        stub_request(:post, "http://localhost:4200/v1/authorize")
          .to_timeout

        response = client.authorize(**params)

        expect(response.success?).to be false
        expect(response.decline_reason).to be_present
      end
    end

    context "when connection fails" do
      it "returns a network error response" do
        stub_request(:post, "http://localhost:4200/v1/authorize")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

        response = client.authorize(**params)

        expect(response.success?).to be false
        expect(response.decline_reason).to include("Connection refused")
      end
    end

    context "when circuit breaker is open" do
      it "returns circuit open response after threshold failures" do
        stub_request(:post, "http://localhost:4200/v1/authorize")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

        # Trip the circuit with 3 failures
        3.times { client.authorize(**params) }

        # Reset stub to verify circuit prevents the call
        WebMock.reset!
        response = client.authorize(**params)

        expect(response.success?).to be false
        expect(response.decline_reason).to eq("circuit_breaker_open")
      end
    end
  end

  describe "#capture" do
    it "sends capture request to network" do
      stub_request(:post, "http://localhost:4200/v1/capture")
        .to_return(
          status: 200,
          body: {
            id: "cap_abc123",
            status: "approved",
            response_code: "00"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      response = client.capture(
        authorization_code: "auth_abc123",
        amount_cents: 5000,
        idempotency_key: "cap_idem_123"
      )

      expect(response.success?).to be true
    end
  end

  describe "#void" do
    it "sends void request to network" do
      stub_request(:post, "http://localhost:4200/v1/void")
        .to_return(
          status: 200,
          body: {
            id: "void_abc123",
            status: "approved"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      response = client.void(
        authorization_code: "auth_abc123",
        idempotency_key: "void_idem_123"
      )

      expect(response.success?).to be true
    end
  end

  describe "#refund" do
    it "sends refund request to network" do
      stub_request(:post, "http://localhost:4200/v1/refund")
        .to_return(
          status: 200,
          body: {
            id: "ref_abc123",
            status: "approved",
            amount: 3000
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      response = client.refund(
        amount_cents: 3000,
        currency: "USD",
        idempotency_key: "ref_idem_123"
      )

      expect(response.success?).to be true
    end
  end

  describe Payments::Services::GatewayResponse do
    describe ".circuit_open" do
      it "returns a failed response with circuit_breaker_open reason" do
        response = described_class.circuit_open
        expect(response.success?).to be false
        expect(response.decline_reason).to eq("circuit_breaker_open")
      end
    end

    describe ".timeout" do
      it "returns a failed response with timeout reason" do
        response = described_class.timeout
        expect(response.success?).to be false
        expect(response.decline_reason).to eq("timeout")
      end
    end

    describe "#to_h" do
      it "serializes response data" do
        response = described_class.circuit_open
        hash = response.to_h

        expect(hash).to include(:status, :authorization_code, :decline_reason, :response_code)
      end
    end
  end
end
