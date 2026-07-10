require "rails_helper"

RSpec.describe Webhooks::Services::WebhookDeliveryService do
  let(:service) { described_class.new }
  let(:merchant) { create(:merchant, :with_webhook) }
  let(:transaction) do
    create(:transaction, merchant: merchant, amount_cents: 10_000, status: "captured", captured_at: Time.current)
  end

  describe "#deliver_payment_captured" do
    it "creates a webhook delivery attempt" do
      expect {
        service.deliver_payment_captured(transaction)
      }.to change(WebhookDeliveryAttempt, :count).by(1)
    end

    it "creates attempt with correct event type" do
      service.deliver_payment_captured(transaction)
      attempt = WebhookDeliveryAttempt.last

      expect(attempt.event_type).to eq("payment.captured")
      expect(attempt.status).to eq("pending")
      expect(attempt.merchant).to eq(merchant)
    end

    it "includes transaction data in payload" do
      service.deliver_payment_captured(transaction)
      attempt = WebhookDeliveryAttempt.last

      payload = attempt.payload
      expect(payload["data"]["transaction_id"]).to eq(transaction.id)
      expect(payload["data"]["amount_cents"]).to eq(10_000)
    end

    it "does nothing if merchant has no webhook URL" do
      merchant.update!(webhook_url_ciphertext: nil)
      expect {
        service.deliver_payment_captured(transaction)
      }.not_to change(WebhookDeliveryAttempt, :count)
    end
  end

  describe "#deliver_payment_failed" do
    let(:failed_transaction) do
      create(:transaction, merchant: merchant, amount_cents: 5000, status: "failed", failure_reason: "declined")
    end

    it "creates a webhook delivery attempt for failure" do
      expect {
        service.deliver_payment_failed(failed_transaction)
      }.to change(WebhookDeliveryAttempt, :count).by(1)

      attempt = WebhookDeliveryAttempt.last
      expect(attempt.event_type).to eq("payment.failed")
      expect(attempt.payload["data"]["failure_reason"]).to eq("declined")
    end
  end

  describe "#deliver_payment_refunded" do
    it "creates a webhook delivery attempt for refund" do
      expect {
        service.deliver_payment_refunded(transaction, refund_amount_cents: 3000)
      }.to change(WebhookDeliveryAttempt, :count).by(1)

      attempt = WebhookDeliveryAttempt.last
      expect(attempt.event_type).to eq("payment.refunded")
      expect(attempt.payload["data"]["refund_amount_cents"]).to eq(3000)
    end
  end
end
