require "rails_helper"

RSpec.describe Fraud::Services::RuleEngine do
  let(:merchant) { create(:merchant) }
  let(:engine) { described_class.new }

  def create_tx(attrs = {})
    create(:transaction, { merchant: merchant, amount_cents: 5000, card_last_four: "4242", card_brand: "visa", status: "pending" }.merge(attrs))
  end

  describe "#evaluate" do
    it "returns a RuleResult" do
      tx = create_tx
      result = engine.evaluate(tx)
      expect(result).to be_a(Fraud::Services::RuleResult)
    end

    it "includes latency_ms" do
      tx = create_tx
      result = engine.evaluate(tx)
      expect(result.latency_ms).to be_a(Float)
      expect(result.latency_ms).to be >= 0
    end

    context "velocity rules" do
      it "triggers rapid_fire_5min for 5+ transactions in 5 minutes" do
        card = "5555"
        5.times { create_tx(card_last_four: card, created_at: 2.minutes.ago) }
        tx = create_tx(card_last_four: card)

        result = engine.evaluate(tx)
        rule_names = result.matched_rules.map { |r| r[:name] }
        expect(rule_names).to include("rapid_fire_5min")
        expect(result.hard_block?).to be true
      end

      it "does not trigger for normal velocity" do
        tx = create_tx
        result = engine.evaluate(tx)
        rule_names = result.matched_rules.map { |r| r[:name] }
        expect(rule_names).not_to include("rapid_fire_5min")
      end
    end

    context "amount rules" do
      it "triggers very_high_amount for $5,000+" do
        tx = create_tx(amount_cents: 500_000)
        result = engine.evaluate(tx)
        rule_names = result.matched_rules.map { |r| r[:name] }
        expect(rule_names).to include("very_high_amount")
      end

      it "triggers extreme_amount (critical) for $10,000+" do
        tx = create_tx(amount_cents: 1_000_000)
        result = engine.evaluate(tx)
        rule_names = result.matched_rules.map { |r| r[:name] }
        expect(rule_names).to include("extreme_amount")
        expect(result.hard_block?).to be true
      end

      it "does not trigger for normal amounts" do
        tx = create_tx(amount_cents: 5000)
        result = engine.evaluate(tx)
        rule_names = result.matched_rules.map { |r| r[:name] }
        expect(rule_names).not_to include("very_high_amount")
      end
    end

    context "round amount rule" do
      it "triggers for round amounts above $1,000" do
        tx = create_tx(amount_cents: 200_000) # $2,000.00 exactly
        result = engine.evaluate(tx)
        rule_names = result.matched_rules.map { |r| r[:name] }
        expect(rule_names).to include("suspicious_round_amount")
      end

      it "does not trigger for non-round amounts" do
        tx = create_tx(amount_cents: 199_999)
        result = engine.evaluate(tx)
        rule_names = result.matched_rules.map { |r| r[:name] }
        expect(rule_names).not_to include("suspicious_round_amount")
      end
    end

    context "time rule" do
      it "triggers for off-hours (2am-5am)" do
        tx = create_tx(created_at: Time.zone.parse("2026-01-15 03:00:00"))
        result = engine.evaluate(tx)
        rule_names = result.matched_rules.map { |r| r[:name] }
        expect(rule_names).to include("off_hours")
      end

      it "does not trigger during business hours" do
        tx = create_tx(created_at: Time.zone.parse("2026-01-15 14:00:00"))
        result = engine.evaluate(tx)
        rule_names = result.matched_rules.map { |r| r[:name] }
        expect(rule_names).not_to include("off_hours")
      end
    end

    context "first transaction rule" do
      it "triggers for first high-value transaction from card" do
        tx = create_tx(card_last_four: "6666", amount_cents: 60_000)
        result = engine.evaluate(tx)
        rule_names = result.matched_rules.map { |r| r[:name] }
        expect(rule_names).to include("first_tx_high_value")
      end

      it "does not trigger if card has history" do
        create_tx(card_last_four: "7777", created_at: 1.day.ago)
        tx = create_tx(card_last_four: "7777", amount_cents: 60_000)
        result = engine.evaluate(tx)
        rule_names = result.matched_rules.map { |r| r[:name] }
        expect(rule_names).not_to include("first_tx_high_value")
      end

      it "does not trigger for low-value first transaction" do
        tx = create_tx(card_last_four: "8888", amount_cents: 5000)
        result = engine.evaluate(tx)
        rule_names = result.matched_rules.map { |r| r[:name] }
        expect(rule_names).not_to include("first_tx_high_value")
      end
    end

    context "hard_block?" do
      it "returns true when any critical severity rule matches" do
        tx = create_tx(amount_cents: 1_000_000)
        result = engine.evaluate(tx)
        expect(result.hard_block?).to be true
      end

      it "returns false when no critical rules match" do
        tx = create_tx(amount_cents: 5000)
        result = engine.evaluate(tx)
        expect(result.hard_block?).to be false
      end
    end
  end
end
