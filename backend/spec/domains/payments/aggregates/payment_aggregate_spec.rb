require "rails_helper"

RSpec.describe Payments::Aggregates::PaymentAggregate do
  let(:aggregate) { described_class.new(SecureRandom.uuid) }
  let(:merchant_id) { SecureRandom.uuid }

  def initiate!(agg = aggregate, **overrides)
    agg.initiate(
      merchant_id: merchant_id,
      amount_cents: 5000,
      currency: "USD",
      idempotency_key: "idem_#{SecureRandom.hex(8)}",
      **overrides
    )
  end

  def authorize!(agg = aggregate)
    agg.authorize(authorization_code: "A12345", network_response: { code: "00" })
  end

  def pass_fraud!(agg = aggregate, score: 0.12)
    agg.pass_fraud_check(score: score, explanation: { velocity: 0.1 }, decision: "pass")
  end

  describe "#initiate" do
    it "transitions from new to initiated" do
      initiate!

      expect(aggregate.unpublished_events.size).to eq(1)
      expect(aggregate.unpublished_events.first).to be_a(Payments::Events::PaymentInitiated)
      expect(aggregate.status).to eq(:initiated)
    end

    it "stores amount and currency" do
      initiate!(amount_cents: 10_000, currency: "EUR")

      expect(aggregate.amount_cents).to eq(10_000)
      expect(aggregate.currency).to eq("EUR")
      expect(aggregate.merchant_id).to eq(merchant_id)
    end

    it "rejects double initiation" do
      initiate!

      expect {
        initiate!
      }.to raise_error(described_class::AlreadyProcessed)
    end
  end

  describe "#authorize" do
    before { initiate! }

    it "transitions from initiated to authorized" do
      authorize!

      expect(aggregate.status).to eq(:authorized)
      expect(aggregate.authorization_code).to eq("A12345")
    end

    it "rejects authorization from wrong state" do
      authorize!
      expect { authorize! }.to raise_error(described_class::InvalidTransition)
    end
  end

  describe "#fail_authorization" do
    before { initiate! }

    it "transitions to failed" do
      aggregate.fail_authorization(reason: "insufficient_funds", network_response: { code: "51" })

      expect(aggregate.status).to eq(:failed)
    end
  end

  describe "#pass_fraud_check" do
    before { initiate!; authorize! }

    it "transitions from authorized to fraud_cleared" do
      pass_fraud!

      expect(aggregate.status).to eq(:fraud_cleared)
      expect(aggregate.fraud_score).to eq(0.12)
    end
  end

  describe "#fail_fraud_check" do
    before { initiate!; authorize! }

    it "transitions to blocked" do
      aggregate.fail_fraud_check(score: 0.95, explanation: {}, matched_rules: ["velocity"])

      expect(aggregate.status).to eq(:blocked)
      expect(aggregate.fraud_score).to eq(0.95)
    end
  end

  describe "#capture" do
    before { initiate!(amount_cents: 10_000); authorize!; pass_fraud! }

    it "captures full amount by default" do
      aggregate.capture

      expect(aggregate.status).to eq(:captured)
      expect(aggregate.captured_amount_cents).to eq(10_000)
    end

    it "supports partial capture" do
      aggregate.capture(amount_cents: 7000)

      expect(aggregate.captured_amount_cents).to eq(7000)
    end

    it "rejects capture exceeding authorization" do
      expect {
        aggregate.capture(amount_cents: 15_000)
      }.to raise_error(ArgumentError, /exceeds authorization/)
    end

    it "cannot capture without fraud check" do
      fresh = described_class.new(SecureRandom.uuid)
      initiate!(fresh)
      authorize!(fresh)

      expect { fresh.capture }.to raise_error(described_class::InvalidTransition)
    end
  end

  describe "#refund" do
    before { initiate!(amount_cents: 10_000); authorize!; pass_fraud!; aggregate.capture }

    it "full refund transitions to refunded" do
      aggregate.refund

      expect(aggregate.status).to eq(:refunded)
      expect(aggregate.refunded_amount_cents).to eq(10_000)
    end

    it "partial refund keeps captured status" do
      aggregate.refund(amount_cents: 3000)

      expect(aggregate.status).to eq(:captured)
      expect(aggregate.refunded_amount_cents).to eq(3000)
    end

    it "allows multiple partial refunds" do
      aggregate.refund(amount_cents: 3000)
      aggregate.refund(amount_cents: 4000)

      expect(aggregate.refunded_amount_cents).to eq(7000)
    end

    it "rejects refund exceeding captured amount" do
      expect {
        aggregate.refund(amount_cents: 15_000)
      }.to raise_error(ArgumentError, /exceeds remaining/)
    end

    it "rejects refund from pending state" do
      fresh = described_class.new(SecureRandom.uuid)
      initiate!(fresh)

      expect { fresh.refund }.to raise_error(described_class::InvalidTransition)
    end
  end

  describe "#void" do
    it "can void an initiated payment" do
      initiate!
      aggregate.void
      expect(aggregate.status).to eq(:voided)
    end

    it "can void an authorized payment" do
      initiate!; authorize!
      aggregate.void
      expect(aggregate.status).to eq(:voided)
    end

    it "cannot void a captured payment" do
      initiate!; authorize!; pass_fraud!; aggregate.capture
      expect { aggregate.void }.to raise_error(described_class::InvalidTransition)
    end
  end

  describe "full lifecycle" do
    it "processes initiate -> authorize -> fraud -> capture -> settle -> refund" do
      initiate!(amount_cents: 10_000)
      authorize!
      pass_fraud!
      aggregate.capture
      aggregate.settle
      aggregate.refund

      events = aggregate.unpublished_events
      expect(events.map(&:class)).to eq([
        Payments::Events::PaymentInitiated,
        Payments::Events::PaymentAuthorized,
        Payments::Events::FraudCheckPassed,
        Payments::Events::PaymentCaptured,
        Payments::Events::PaymentSettled,
        Payments::Events::PaymentRefunded
      ])
    end
  end

  describe "event data integrity" do
    it "stores all required fields in PaymentInitiated" do
      initiate!(amount_cents: 7500, currency: "USD", card_last_four: "4242")

      event = aggregate.unpublished_events.first
      expect(event.data[:transaction_id]).to be_present
      expect(event.data[:merchant_id]).to eq(merchant_id)
      expect(event.data[:amount_cents]).to eq(7500)
      expect(event.data[:currency]).to eq("USD")
      expect(event.data[:idempotency_key]).to be_present
    end
  end
end
