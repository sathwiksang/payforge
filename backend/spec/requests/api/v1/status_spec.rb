require "rails_helper"

RSpec.describe "Api::V1::Status", type: :request do
  let(:user) { create(:user, :admin) }
  let(:headers) { auth_headers_for(user) }

  describe "GET /api/v1/status" do
    it "returns operational status" do
      get "/api/v1/status", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response[:data][:status]).to eq("operational")
      expect(json_response[:data][:version]).to eq("v1")
      expect(json_response[:meta][:request_id]).to be_present
    end
  end
end
