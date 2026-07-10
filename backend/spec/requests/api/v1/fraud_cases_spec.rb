require "rails_helper"

RSpec.describe "Api::V1::FraudCases", type: :request do
  let(:merchant) { create(:merchant) }
  let(:admin_user) { create(:user, :admin, merchant: merchant) }
  let(:headers) { auth_headers_for(admin_user) }

  describe "GET /api/v1/fraud/cases" do
    it "returns paginated fraud cases" do
      create_list(:fraud_case, 3, merchant: merchant)

      get "/api/v1/fraud/cases", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data].length).to eq(3)
      expect(json_response[:meta][:total_count]).to eq(3)
    end

    it "filters by status" do
      create(:fraud_case, merchant: merchant, status: "open")
      create(:fraud_case, :resolved, merchant: merchant)

      get "/api/v1/fraud/cases", params: { status: "open" }, headers: headers
      expect(json_response[:data].length).to eq(1)
    end

    it "denies access to viewers" do
      viewer = create(:user, merchant: merchant)
      get "/api/v1/fraud/cases", headers: auth_headers_for(viewer)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/fraud/cases/:id" do
    let!(:fraud_case) { create(:fraud_case, merchant: merchant) }

    it "returns case details" do
      get "/api/v1/fraud/cases/#{fraud_case.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data][:id]).to eq(fraud_case.id)
      expect(json_response[:data][:risk_score]).to be_present
    end
  end

  describe "POST /api/v1/fraud/cases/:id/review" do
    let!(:fraud_case) { create(:fraud_case, merchant: merchant) }

    it "resolves a fraud case" do
      post "/api/v1/fraud/cases/#{fraud_case.id}/review",
        params: { status: "false_positive", notes: "Verified customer" },
        headers: headers
      expect(response).to have_http_status(:ok)
      expect(fraud_case.reload.status).to eq("false_positive")
    end
  end

  describe "GET /api/v1/fraud/stats" do
    it "returns fraud statistics" do
      create(:fraud_case, merchant: merchant, status: "open")
      create(:fraud_case, :blocked, merchant: merchant, status: "confirmed_fraud")

      get "/api/v1/fraud/stats", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data][:total_cases]).to eq(2)
      expect(json_response[:data][:open_cases]).to eq(1)
      expect(json_response[:data][:by_priority]).to be_present
    end
  end
end
