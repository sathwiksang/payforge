require "rails_helper"

RSpec.describe "Api::V1::ApiKeys", type: :request do
  let(:merchant) { create(:merchant) }
  let(:user) { create(:user, :admin, merchant: merchant) }
  let(:headers) { auth_headers_for(user) }

  describe "GET /api/v1/api_keys" do
    it "returns merchant API keys" do
      ApiKey.generate_for(merchant: merchant, name: "Test Key")
      get "/api/v1/api_keys", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data].length).to eq(1)
      expect(json_response[:data].first[:name]).to eq("Test Key")
    end
  end

  describe "POST /api/v1/api_keys" do
    it "creates a new API key and returns the secret" do
      post "/api/v1/api_keys", params: { name: "My Key", environment: "test" }, headers: headers
      expect(response).to have_http_status(:created)
      expect(json_response[:data][:secret_key]).to start_with("pk_test_")
      expect(json_response[:meta][:warning]).to include("Store this key")
    end
  end

  describe "DELETE /api/v1/api_keys/:id" do
    it "revokes an API key" do
      key, _ = ApiKey.generate_for(merchant: merchant, name: "Revocable")
      delete "/api/v1/api_keys/#{key.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(key.reload.revoked?).to be true
    end
  end

  describe "POST /api/v1/api_keys/:id/rotate" do
    it "rotates an API key" do
      key, _ = ApiKey.generate_for(merchant: merchant, name: "Rotatable")
      post "/api/v1/api_keys/#{key.id}/rotate", headers: headers
      expect(response).to have_http_status(:created)
      expect(json_response[:data][:secret_key]).to start_with("pk_test_")
      expect(json_response[:meta][:rotated_from]).to eq(key.id)
      expect(key.reload.revoked?).to be true
    end
  end
end
