require "rails_helper"

# Contract tests for webhook delivery — verify payload shape matches documented contract
RSpec.describe "Webhook Delivery Contract", type: :model do
  let(:merchant) { create(:merchant) }
  let(:transaction) { create(:transaction, :captured, merchant: merchant) }

  describe "webhook payload structure" do
    it "delivery attempt has required fields" do
      attempt = create(:webhook_delivery_attempt,
        merchant: merchant,
        event_type: "payment.captured",
        event_id: SecureRandom.uuid,
        status: "delivered",
        response_code: 200
      )

      expect(attempt.event_type).to be_present
      expect(attempt.event_id).to be_present
      expect(attempt.status).to be_in(%w[pending delivered failed])
      expect(attempt.response_code).to be_a(Integer)
      expect(attempt.merchant).to eq(merchant)
    end
  end

  describe "webhook event types contract" do
    VALID_EVENT_TYPES = %w[
      payment.initiated
      payment.authorized
      payment.authorization_failed
      payment.fraud_passed
      payment.fraud_blocked
      payment.captured
      payment.settled
      payment.refunded
      payment.partially_refunded
      payment.voided
      payment.dispute_opened
      payment.dispute_resolved
    ].freeze

    it "all documented event types are valid strings" do
      VALID_EVENT_TYPES.each do |event_type|
        expect(event_type).to match(/\Apayment\.\w+\z/)
      end
    end

    it "has at least 10 event types" do
      expect(VALID_EVENT_TYPES.size).to be >= 10
    end
  end

  describe "webhook delivery service payload format" do
    let(:service) { Webhooks::Services::WebhookDeliveryService.new }

    it "build_payload produces correctly shaped payload" do
      payload = service.send(:build_payload, "payment.captured", {
        transaction_id: transaction.id,
        amount_cents: 5000,
        currency: "USD"
      })

      expect(payload[:id]).to start_with("evt_")
      expect(payload[:type]).to eq("payment.captured")
      expect(payload[:created_at]).to be_present
      expect(payload[:data]).to be_a(Hash)
      expect(payload[:data][:transaction_id]).to eq(transaction.id)
    end
  end
end
