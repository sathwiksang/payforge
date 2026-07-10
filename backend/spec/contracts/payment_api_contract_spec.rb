require "rails_helper"

# API contract tests — verify the shape and types of API responses
# These serve the same purpose as Pact consumer tests without requiring
# a separate broker. They validate the frontend-backend contract.
RSpec.describe "Payment API Contract", type: :request do
  let(:merchant) { create(:merchant) }
  let(:admin_user) { create(:user, :admin, merchant: merchant) }
  let(:headers) { auth_headers_for(admin_user) }

  describe "GET /api/v1/transactions/:id" do
    let!(:transaction) { create(:transaction, :captured, merchant: merchant) }

    it "returns data matching the contract schema" do
      get "/api/v1/transactions/#{transaction.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = json_response

      # Top-level structure
      expect(body).to have_key(:data)
      expect(body).to have_key(:meta)

      # Data fields from TransactionBlueprint
      data = body[:data]
      expect(data[:id]).to be_a(String)
      expect(data[:status]).to be_a(String)
      expect(data[:status]).to be_in(%w[initiated authorized captured settled failed refunded blocked voided pending])
      expect(data[:amount_cents]).to be_a(Integer).or be_nil
      expect(data[:currency]).to be_a(String)
      expect(data[:amount]).to be_a(Hash)
      expect(data[:amount][:cents]).to be_a(Integer)
      expect(data[:amount][:currency]).to eq(transaction.currency)

      # Meta fields
      meta = body[:meta]
      expect(meta[:request_id]).to be_a(String)
      expect(meta[:processing_time_ms]).to be_a(Integer)
    end
  end

  describe "GET /api/v1/transactions (list)" do
    before { create_list(:transaction, 3, merchant: merchant) }

    it "returns paginated list matching the contract schema" do
      get "/api/v1/transactions", headers: headers

      expect(response).to have_http_status(:ok)
      body = json_response

      # List structure
      expect(body[:data]).to be_an(Array)
      expect(body[:meta]).to have_key(:total_count)
      expect(body[:meta]).to have_key(:page)
      expect(body[:meta]).to have_key(:per_page)
      expect(body[:meta]).to have_key(:total_pages)
      expect(body[:links]).to have_key(:self)

      # Pagination values are integers
      expect(body[:meta][:total_count]).to be_a(Integer)
      expect(body[:meta][:page]).to be_a(Integer)
      expect(body[:meta][:per_page]).to be_a(Integer)
      expect(body[:meta][:total_pages]).to be_a(Integer)

      # Each item has expected fields
      body[:data].each do |item|
        expect(item[:id]).to be_present
        expect(item[:status]).to be_present
        expect(item[:amount]).to be_a(Hash)
      end
    end
  end

  describe "POST /api/v1/transactions (create payment)" do
    it "returns 201 with created payment matching schema" do
      post "/api/v1/transactions",
        params: {
          transaction: {
            amount_cents: 5000,
            currency: "USD",
            card_last_four: "4242",
            card_brand: "visa",
            idempotency_key: "idem_contract_#{SecureRandom.hex(8)}"
          }
        }.to_json,
        headers: headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:created)
      body = json_response

      expect(body[:data]).to be_present
      expect(body[:data][:id]).to be_a(String)
      expect(body[:data][:status]).to be_a(String)
      expect(body[:data][:amount]).to be_a(Hash)
      expect(body[:data][:amount][:cents]).to eq(5000)
      expect(body[:meta]).to have_key(:request_id)
    end
  end

  describe "error response contract" do
    it "returns standardized error format for 404" do
      get "/api/v1/transactions/#{SecureRandom.uuid}", headers: headers

      expect(response).to have_http_status(:not_found)
      body = json_response

      expect(body).to have_key(:error)
      expect(body[:error]).to have_key(:message)
      expect(body[:error]).to have_key(:code)
      expect(body[:error]).to have_key(:type)
      expect(body).to have_key(:meta)
      expect(body[:meta]).to have_key(:request_id)
    end

    it "returns standardized error format for validation errors" do
      post "/api/v1/transactions",
        params: { transaction: { amount_cents: 1 } }.to_json,
        headers: headers.merge("Content-Type" => "application/json")

      expect(response.status).to be_in([422, 400])
      body = json_response

      expect(body).to have_key(:error)
      expect(body[:error]).to have_key(:message)
    end

    it "returns 401 for unauthenticated requests" do
      get "/api/v1/transactions"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
