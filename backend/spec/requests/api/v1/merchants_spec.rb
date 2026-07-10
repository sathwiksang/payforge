require "rails_helper"

RSpec.describe "Api::V1::Merchants", type: :request do
  let(:merchant) { create(:merchant) }
  let(:admin_user) { create(:user, :admin, merchant: merchant) }
  let(:admin_headers) { auth_headers_for(admin_user) }

  describe "GET /api/v1/merchants/me" do
    it "returns the current merchant profile" do
      get "/api/v1/merchants/me", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data][:id]).to eq(merchant.id)
    end

    it "returns 401 without auth" do
      get "/api/v1/merchants/me"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/merchants/me" do
    it "updates the merchant profile" do
      patch "/api/v1/merchants/me", params: { name: "Updated Corp" }, headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(merchant.reload.name).to eq("Updated Corp")
    end
  end

  describe "GET /api/v1/merchants/me/analytics" do
    it "returns analytics data" do
      get "/api/v1/merchants/me/analytics", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data]).to be_present
    end
  end

  describe "GET /api/v1/merchants/me/balance" do
    it "returns balance data" do
      get "/api/v1/merchants/me/balance", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data]).to be_an(Array)
    end
  end

  describe "GET /api/v1/merchants (admin)" do
    it "lists all merchants for admins" do
      create_list(:merchant, 3)
      get "/api/v1/merchants", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data].length).to be >= 3
    end

    it "denies access to non-admins" do
      viewer = create(:user, merchant: merchant)
      get "/api/v1/merchants", headers: auth_headers_for(viewer)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/merchants" do
    it "creates a new merchant" do
      post "/api/v1/merchants",
        params: { name: "New Corp", email: "new@corp.com", status: "active",
                  fee_percentage: 2.5, fee_fixed_cents: 25, risk_tier: "standard" },
        headers: admin_headers
      expect(response).to have_http_status(:created)
      expect(json_response[:data][:name]).to eq("New Corp")
    end
  end

  describe "GET /api/v1/merchants/:id" do
    it "returns a specific merchant" do
      get "/api/v1/merchants/#{merchant.id}", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data][:id]).to eq(merchant.id)
    end
  end
end
