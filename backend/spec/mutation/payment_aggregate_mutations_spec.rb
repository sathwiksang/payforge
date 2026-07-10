require "rails_helper"

# Mutation-equivalent tests for Payments::Aggregates::PaymentAggregate
# Targets: state transitions, guard conditions, event data, boundary values
RSpec.describe Payments::Aggregates::PaymentAggregate, "mutation coverage" do
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

  # -- State transition mutations --

  describe "state machine completeness" do
    it "starts in :new state (mutation: change initial state)" do
      expect(aggregate.status).to eq(:new)
    end

    it "initiate transitions to :initiated, not :authorized (mutation: wrong target state)" do
      initiate!
      expect(aggregate.status).to eq(:initiated)
      expect(aggregate.status).not_to eq(:authorized)
    end

    it "authorize transitions to :authorized, not :initiated (mutation: no-op transition)" do
      initiate!
      authorize!
      expect(aggregate.status).to eq(:authorized)
      expect(aggregate.status).not_to eq(:initiated)
    end

    it "pass_fraud_check transitions to :fraud_cleared, not :authorized (mutation: skip)" do
      initiate!; authorize!
      pass_fraud!
      expect(aggregate.status).to eq(:fraud_cleared)
    end

    it "fail_fraud_check transitions to :blocked (mutation: wrong status)" do
      initiate!; authorize!
      aggregate.fail_fraud_check(score: 0.95, explanation: {}, matched_rules: ["velocity"])
      expect(aggregate.status).to eq(:blocked)
      expect(aggregate.status).not_to eq(:fraud_cleared)
    end

    it "fail_authorization transitions to :failed (mutation: wrong status)" do
      initiate!
      aggregate.fail_authorization(reason: "declined", network_response: { code: "51" })
      expect(aggregate.status).to eq(:failed)
      expect(aggregate.status).not_to eq(:initiated)
    end

    it "capture transitions to :captured (mutation: wrong status)" do
      initiate!; authorize!; pass_fraud!
      aggregate.capture
      expect(aggregate.status).to eq(:captured)
    end

    it "settle transitions to :settled (mutation: remain :captured)" do
      initiate!; authorize!; pass_fraud!; aggregate.capture
      aggregate.settle
      expect(aggregate.status).to eq(:settled)
      expect(aggregate.status).not_to eq(:captured)
    end

    it "void transitions to :voided (mutation: wrong status)" do
      initiate!
      aggregate.void
      expect(aggregate.status).to eq(:voided)
    end
  end

  # -- Guard condition mutations --

  describe "guard conditions" do
    it "cannot initiate twice (mutation: remove AlreadyProcessed check)" do
      initiate!
      expect { initiate! }.to raise_error(described_class::AlreadyProcessed)
    end

    it "cannot authorize from :new (mutation: wrong guard state)" do
      expect { authorize! }.to raise_error(described_class::InvalidTransition)
    end

    it "cannot authorize from :authorized (mutation: allow re-authorization)" do
      initiate!; authorize!
      expect { authorize! }.to raise_error(described_class::InvalidTransition)
    end

    it "cannot fail authorization from :authorized (mutation: wrong guard)" do
      initiate!; authorize!
      expect {
        aggregate.fail_authorization(reason: "x", network_response: {})
      }.to raise_error(described_class::InvalidTransition)
    end

    it "cannot pass fraud from :initiated (mutation: skip authorize requirement)" do
      initiate!
      expect {
        pass_fraud!
      }.to raise_error(described_class::InvalidTransition)
    end

    it "cannot capture from :authorized (mutation: skip fraud check requirement)" do
      initiate!; authorize!
      expect { aggregate.capture }.to raise_error(described_class::InvalidTransition)
    end

    it "cannot capture from :initiated (mutation: accept any state)" do
      initiate!
      expect { aggregate.capture }.to raise_error(described_class::InvalidTransition)
    end

    it "cannot settle from :authorized (mutation: skip capture requirement)" do
      initiate!; authorize!
      expect { aggregate.settle }.to raise_error(described_class::InvalidTransition)
    end

    it "cannot refund from :initiated (mutation: accept any state)" do
      initiate!
      expect { aggregate.refund }.to raise_error(described_class::InvalidTransition)
    end

    it "cannot refund from :authorized (mutation: accept any state)" do
      initiate!; authorize!
      expect { aggregate.refund }.to raise_error(described_class::InvalidTransition)
    end

    it "cannot void from :captured (mutation: accept any state)" do
      initiate!; authorize!; pass_fraud!; aggregate.capture
      expect { aggregate.void }.to raise_error(described_class::InvalidTransition)
    end

    it "cannot void from :refunded (mutation: accept terminal states)" do
      initiate!(amount_cents: 5000); authorize!; pass_fraud!; aggregate.capture; aggregate.refund
      expect { aggregate.void }.to raise_error(described_class::InvalidTransition)
    end
  end

  # -- Amount boundary mutations --

  describe "capture amount boundaries" do
    before { initiate!(amount_cents: 10_000); authorize!; pass_fraud! }

    it "defaults to full amount when no amount_cents given (mutation: default to 0)" do
      aggregate.capture
      expect(aggregate.captured_amount_cents).to eq(10_000)
    end

    it "partial capture stores the partial amount (mutation: ignore parameter)" do
      aggregate.capture(amount_cents: 7000)
      expect(aggregate.captured_amount_cents).to eq(7000)
      expect(aggregate.captured_amount_cents).not_to eq(10_000)
    end

    it "capture of 0 is valid but unusual (allowed since 0 <= authorized amount)" do
      # The aggregate only checks capture_amount > @amount_cents
      # 0 <= 10_000, so it doesn't raise — this is by design
      aggregate.capture(amount_cents: 0)
      expect(aggregate.captured_amount_cents).to eq(0)
    end

    it "rejects capture exceeding authorization (mutation: flip > to >=)" do
      expect { aggregate.capture(amount_cents: 10_001) }.to raise_error(ArgumentError, /exceeds authorization/)
    end

    it "allows capture of exact authorization amount (mutation: flip >= to >)" do
      expect { aggregate.capture(amount_cents: 10_000) }.not_to raise_error
    end
  end

  describe "refund amount boundaries" do
    before { initiate!(amount_cents: 10_000); authorize!; pass_fraud!; aggregate.capture }

    it "defaults to full captured amount (mutation: default to 0)" do
      aggregate.refund
      expect(aggregate.refunded_amount_cents).to eq(10_000)
    end

    it "partial refund tracks amount (mutation: ignore parameter)" do
      aggregate.refund(amount_cents: 3000)
      expect(aggregate.refunded_amount_cents).to eq(3000)
    end

    it "accumulates multiple partial refunds (mutation: overwrite instead of add)" do
      aggregate.refund(amount_cents: 3000)
      aggregate.refund(amount_cents: 4000)
      expect(aggregate.refunded_amount_cents).to eq(7000)
    end

    it "rejects refund exceeding remaining (mutation: remove guard)" do
      expect { aggregate.refund(amount_cents: 10_001) }.to raise_error(ArgumentError, /exceeds remaining/)
    end

    it "rejects refund after full refund (mutation: allow double refund)" do
      aggregate.refund
      expect(aggregate.status).to eq(:refunded)
      expect { aggregate.refund(amount_cents: 1) }.to raise_error(described_class::InvalidTransition)
    end

    it "allows exact remaining refund (mutation: flip >= to >)" do
      aggregate.refund(amount_cents: 5000)
      expect { aggregate.refund(amount_cents: 5000) }.not_to raise_error
    end

    it "full refund transitions to :refunded (mutation: stay :captured)" do
      aggregate.refund
      expect(aggregate.status).to eq(:refunded)
    end

    it "partial refund stays :captured (mutation: transition to :refunded)" do
      aggregate.refund(amount_cents: 1000)
      expect(aggregate.status).to eq(:captured)
    end
  end

  # -- Event data mutations --

  describe "event data integrity" do
    it "PaymentInitiated contains all required fields" do
      initiate!(amount_cents: 7500, currency: "EUR")
      event = aggregate.unpublished_events.first
      data = event.data

      expect(data[:transaction_id]).to eq(aggregate.instance_variable_get(:@id))
      expect(data[:merchant_id]).to eq(merchant_id)
      expect(data[:amount_cents]).to eq(7500)
      expect(data[:currency]).to eq("EUR")
      expect(data[:idempotency_key]).to be_present
    end

    it "PaymentAuthorized stores authorization_code (mutation: omit field)" do
      initiate!; authorize!
      event = aggregate.unpublished_events.find { |e| e.is_a?(Payments::Events::PaymentAuthorized) }
      expect(event.data[:authorization_code]).to eq("A12345")
    end

    it "FraudCheckPassed stores score (mutation: omit or hardcode)" do
      initiate!; authorize!
      pass_fraud!(score: 0.42)
      expect(aggregate.fraud_score).to eq(0.42)
    end

    it "FraudCheckFailed stores score (mutation: store 0)" do
      initiate!; authorize!
      aggregate.fail_fraud_check(score: 0.95, explanation: {}, matched_rules: [])
      expect(aggregate.fraud_score).to eq(0.95)
    end

    it "PaymentCaptured stores amount (mutation: omit)" do
      initiate!(amount_cents: 8000); authorize!; pass_fraud!
      aggregate.capture(amount_cents: 6000)
      event = aggregate.unpublished_events.find { |e| e.is_a?(Payments::Events::PaymentCaptured) }
      expect(event.data[:amount_cents]).to eq(6000)
    end

    it "uses PaymentPartiallyRefunded for partial and PaymentRefunded for full" do
      initiate!(amount_cents: 10_000); authorize!; pass_fraud!; aggregate.capture

      aggregate.refund(amount_cents: 3000)
      partial_event = aggregate.unpublished_events.to_a.last
      expect(partial_event).to be_a(Payments::Events::PaymentPartiallyRefunded)

      # After 3000 partial, remaining is 7000. Full remaining triggers PaymentRefunded.
      agg2 = described_class.new(SecureRandom.uuid)
      initiate!(agg2, amount_cents: 10_000)
      authorize!(agg2)
      pass_fraud!(agg2)
      agg2.capture
      agg2.refund  # Full refund
      full_event = agg2.unpublished_events.to_a.last
      expect(full_event).to be_a(Payments::Events::PaymentRefunded)
    end
  end

  # -- Attribute storage mutations --

  describe "attribute storage via event handlers" do
    it "stores amount_cents from initiation (mutation: store nil)" do
      initiate!(amount_cents: 9999)
      expect(aggregate.amount_cents).to eq(9999)
    end

    it "stores currency from initiation (mutation: store nil)" do
      initiate!(currency: "GBP")
      expect(aggregate.currency).to eq("GBP")
    end

    it "stores merchant_id from initiation (mutation: store nil)" do
      initiate!
      expect(aggregate.merchant_id).to eq(merchant_id)
    end

    it "initializes captured_amount_cents to 0 (mutation: nil)" do
      expect(aggregate.captured_amount_cents).to eq(0)
    end

    it "initializes refunded_amount_cents to 0 (mutation: nil)" do
      expect(aggregate.refunded_amount_cents).to eq(0)
    end
  end
end
