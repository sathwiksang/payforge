require "rails_helper"

RSpec.describe "Api::V1::Transactions", type: :request do
  let(:merchant) { create(:merchant) }
  let(:user) { create(:user, :admin, merchant: merchant) }
  let(:headers) { auth_headers_for(user) }

  describe "GET /api/v1/transactions" do
    it "returns paginated transactions" do
      create_list(:transaction, 3, merchant: merchant)

      get "/api/v1/transactions", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data].length).to eq(3)
      expect(json_response[:meta][:total_count]).to eq(3)
      expect(json_response[:meta][:page]).to eq(1)
      expect(json_response[:links][:self]).to be_present
    end

    it "filters by status" do
      create(:transaction, merchant: merchant, status: "pending")
      create(:transaction, :captured, merchant: merchant)

      get "/api/v1/transactions", params: { status: "captured" }, headers: headers
      expect(json_response[:data].length).to eq(1)
      expect(json_response[:data].first[:status]).to eq("captured")
    end

    it "filters by amount range" do
      create(:transaction, merchant: merchant, amount_cents: 1000)
      create(:transaction, merchant: merchant, amount_cents: 50_000)

      get "/api/v1/transactions", params: { min_amount: 10_000 }, headers: headers
      expect(json_response[:data].length).to eq(1)
    end

    it "returns 401 without auth" do
      get "/api/v1/transactions"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/transactions/:id" do
    let!(:txn) { create(:transaction, merchant: merchant) }

    it "returns transaction detail" do
      get "/api/v1/transactions/#{txn.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data][:id]).to eq(txn.id)
      expect(json_response[:data][:status]).to eq("pending")
      expect(json_response[:data][:amount][:cents]).to eq(txn.amount_cents)
    end

    it "returns 404 for nonexistent" do
      get "/api/v1/transactions/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/transactions" do
    let(:manager_user) { create(:user, :manager, merchant: merchant) }
    let(:manager_headers) { auth_headers_for(manager_user) }

    let(:valid_params) do
      {
        transaction: {
          amount_cents: 5000,
          currency: "USD",
          card_last_four: "4242",
          card_brand: "visa",
          idempotency_key: "idem_#{SecureRandom.hex(8)}"
        }
      }
    end

    it "creates a transaction" do
      post "/api/v1/transactions", params: valid_params, headers: manager_headers
      expect(response).to have_http_status(:created)
      expect(json_response[:data][:status]).to eq("pending")
      expect(json_response[:data][:amount][:cents]).to eq(5000)
    end

    it "rejects invalid amount" do
      post "/api/v1/transactions",
        params: { transaction: valid_params[:transaction].merge(amount_cents: 10) },
        headers: manager_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/transactions/:id/events" do
    let!(:txn) { create(:transaction, merchant: merchant) }

    it "returns event stream" do
      get "/api/v1/transactions/#{txn.id}/events", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data]).to be_an(Array)
    end
  end

  describe "GET /api/v1/transactions/:id/ledger" do
    let!(:txn) { create(:transaction, merchant: merchant) }

    it "returns ledger entries" do
      get "/api/v1/transactions/#{txn.id}/ledger", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data]).to be_an(Array)
    end
  end
end
