require "rails_helper"

RSpec.describe "Api::V1::Webhooks", type: :request do
  let(:merchant) { create(:merchant, :with_webhook) }
  let(:user) { create(:user, :admin, merchant: merchant) }
  let(:headers) { auth_headers_for(user) }

  describe "GET /api/v1/webhooks/deliveries" do
    it "returns paginated webhook deliveries" do
      create(:webhook_delivery_attempt, merchant: merchant, event_type: "payment.captured")

      get "/api/v1/webhooks/deliveries", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data].length).to eq(1)
      expect(json_response[:data].first[:event_type]).to eq("payment.captured")
    end
  end

  describe "POST /api/v1/webhooks/test" do
    it "sends a test webhook" do
      post "/api/v1/webhooks/test", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data][:event]).to eq("test.ping")
    end

    it "returns error when no webhook URL configured" do
      merchant_no_webhook = create(:merchant)
      user_no_webhook = create(:user, :admin, merchant: merchant_no_webhook)
      post "/api/v1/webhooks/test", headers: auth_headers_for(user_no_webhook)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/webhooks/status" do
    it "returns webhook configuration status" do
      get "/api/v1/webhooks/status", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data][:webhook_configured]).to be true
      expect(json_response[:data][:success_rate]).to be_a(Numeric)
    end
  end
end
