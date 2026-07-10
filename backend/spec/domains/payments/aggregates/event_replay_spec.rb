require "rails_helper"

RSpec.describe "Event Replay", type: :model do
  let(:event_store) { Rails.configuration.event_store }
  let(:merchant) { create(:merchant) }
  let(:merchant_id) { merchant.id }
  let(:transaction_id) { SecureRandom.uuid }
  let(:stream_name) { "Payment$#{transaction_id}" }

  def build_aggregate_from_events
    aggregate = Payments::Aggregates::PaymentAggregate.new(transaction_id)

    aggregate.initiate(
      merchant_id: merchant_id,
      amount_cents: 10_000,
      currency: "USD",
      idempotency_key: "replay_test"
    )
    aggregate.authorize(authorization_code: "AREPLAY", network_response: { code: "00" })
    aggregate.pass_fraud_check(score: 0.08, explanation: { velocity: 0.05 }, decision: "pass")
    aggregate.capture(amount_cents: 10_000)
    aggregate.refund(amount_cents: 3000)

    aggregate
  end

  describe "replaying events produces identical state" do
    it "reconstructs the same aggregate state from stored events" do
      original = build_aggregate_from_events
      events = original.unpublished_events.map(&:dup)

      events.each do |event|
        event_store.publish(event, stream_name: stream_name)
      end

      replayed = Payments::Aggregates::PaymentAggregate.new(transaction_id)
      stored_events = event_store.read.stream(stream_name).to_a
      stored_events.each { |event| replayed.apply(event) }

      expect(replayed.status).to eq(original.status)
      expect(replayed.amount_cents).to eq(original.amount_cents)
      expect(replayed.currency).to eq(original.currency)
      expect(replayed.merchant_id).to eq(original.merchant_id)
      expect(replayed.captured_amount_cents).to eq(original.captured_amount_cents)
      expect(replayed.refunded_amount_cents).to eq(original.refunded_amount_cents)
      expect(replayed.authorization_code).to eq(original.authorization_code)
      expect(replayed.fraud_score).to eq(original.fraud_score)
    end

    it "preserves event ordering" do
      original = build_aggregate_from_events
      events = original.unpublished_events.map(&:dup)

      events.each do |event|
        event_store.publish(event, stream_name: stream_name)
      end

      stored = event_store.read.stream(stream_name).to_a
      expect(stored.map(&:class)).to eq([
        Payments::Events::PaymentInitiated,
        Payments::Events::PaymentAuthorized,
        Payments::Events::FraudCheckPassed,
        Payments::Events::PaymentCaptured,
        Payments::Events::PaymentPartiallyRefunded
      ])
    end

    it "supports replaying to a specific point in time" do
      original = build_aggregate_from_events
      events = original.unpublished_events.map(&:dup)

      events.each do |event|
        event_store.publish(event, stream_name: stream_name)
      end

      partial = Payments::Aggregates::PaymentAggregate.new(transaction_id)
      stored_events = event_store.read.stream(stream_name).to_a

      stored_events.first(3).each { |event| partial.apply(event) }

      expect(partial.status).to eq(:fraud_cleared)
      expect(partial.captured_amount_cents).to eq(0)
      expect(partial.refunded_amount_cents).to eq(0)
    end
  end
end
