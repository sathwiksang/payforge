require "rails_helper"

RSpec.describe Payments::ReadModels::TransactionReadModel do
  let(:projection) { described_class.new }
  let(:merchant) { create(:merchant) }
  let(:transaction_id) { SecureRandom.uuid }

  def publish(event_class, **data)
    event = event_class.new(data: { transaction_id: transaction_id, **data })
    projection.call(event)
  end

  describe "PaymentInitiated" do
    it "creates a transaction record" do
      publish(Payments::Events::PaymentInitiated,
        merchant_id: merchant.id,
        idempotency_key: "idem_test",
        amount_cents: 5000,
        currency: "USD",
        card_last_four: "4242",
        card_brand: "visa",
        metadata: { source: "api" }
      )

      txn = Transaction.find(transaction_id)
      expect(txn.status).to eq("initiated")
      expect(txn.amount_cents).to eq(5000)
      expect(txn.currency).to eq("USD")
      expect(txn.card_last_four).to eq("4242")
      expect(txn.merchant_id).to eq(merchant.id)
    end
  end

  describe "PaymentAuthorized" do
    before do
      publish(Payments::Events::PaymentInitiated,
        merchant_id: merchant.id,
        idempotency_key: "idem_auth",
        amount_cents: 5000,
        currency: "USD"
      )
    end

    it "updates status to authorized" do
      publish(Payments::Events::PaymentAuthorized,
        authorization_code: "A12345",
        authorized_at: Time.current
      )

      txn = Transaction.find(transaction_id)
      expect(txn.status).to eq("authorized")
      expect(txn.authorization_code).to eq("A12345")
      expect(txn.authorized_at).to be_present
    end
  end

  describe "FraudCheckPassed" do
    before do
      publish(Payments::Events::PaymentInitiated,
        merchant_id: merchant.id, idempotency_key: "idem_fraud",
        amount_cents: 5000, currency: "USD")
      publish(Payments::Events::PaymentAuthorized,
        authorization_code: "A123", authorized_at: Time.current)
    end

    it "records fraud score and decision" do
      publish(Payments::Events::FraudCheckPassed,
        score: 0.15, explanation: { velocity: 0.1 }, decision: "pass")

      txn = Transaction.find(transaction_id)
      expect(txn.fraud_score).to eq(0.15)
      expect(txn.fraud_decision).to eq("pass")
      expect(txn.fraud_explanation).to eq({ "velocity" => 0.1 })
    end
  end

  describe "FraudCheckFailed" do
    before do
      publish(Payments::Events::PaymentInitiated,
        merchant_id: merchant.id, idempotency_key: "idem_fraud_fail",
        amount_cents: 5000, currency: "USD")
      publish(Payments::Events::PaymentAuthorized,
        authorization_code: "A123", authorized_at: Time.current)
    end

    it "blocks the transaction" do
      publish(Payments::Events::FraudCheckFailed,
        score: 0.92, explanation: {}, matched_rules: ["high_velocity"])

      txn = Transaction.find(transaction_id)
      expect(txn.status).to eq("blocked")
      expect(txn.fraud_decision).to eq("block")
    end
  end

  describe "full lifecycle projection" do
    it "tracks all state changes through events" do
      publish(Payments::Events::PaymentInitiated,
        merchant_id: merchant.id, idempotency_key: "idem_full",
        amount_cents: 10_000, currency: "USD")
      expect(Transaction.find(transaction_id).status).to eq("initiated")

      publish(Payments::Events::PaymentAuthorized,
        authorization_code: "A999", authorized_at: Time.current)
      expect(Transaction.find(transaction_id).status).to eq("authorized")

      publish(Payments::Events::FraudCheckPassed,
        score: 0.05, explanation: {}, decision: "pass")

      publish(Payments::Events::PaymentCaptured, captured_at: Time.current)
      expect(Transaction.find(transaction_id).status).to eq("captured")

      publish(Payments::Events::PaymentSettled, settled_at: Time.current)
      expect(Transaction.find(transaction_id).status).to eq("settled")

      publish(Payments::Events::PaymentRefunded, refunded_at: Time.current)
      expect(Transaction.find(transaction_id).status).to eq("refunded")
    end
  end

  describe "PaymentVoided" do
    it "sets status to voided" do
      publish(Payments::Events::PaymentInitiated,
        merchant_id: merchant.id, idempotency_key: "idem_void",
        amount_cents: 3000, currency: "USD")

      publish(Payments::Events::PaymentVoided, voided_at: Time.current)

      expect(Transaction.find(transaction_id).status).to eq("voided")
    end
  end

  describe "resilience" do
    it "handles events for missing transactions gracefully" do
      expect {
        publish(Payments::Events::PaymentCaptured, captured_at: Time.current)
      }.not_to raise_error
    end
  end
end
