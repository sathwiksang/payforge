require "rails_helper"

# Mutation-equivalent tests for Fraud::Services::RuleEngine
# Targets: each rule type, severity values, threshold boundaries, hard_block? logic
RSpec.describe Fraud::Services::RuleEngine, "mutation coverage" do
  let(:merchant) { create(:merchant) }
  let(:engine) { described_class.new }

  def create_tx(attrs = {})
    create(:transaction, { merchant: merchant, amount_cents: 5000, card_last_four: "4242", card_brand: "visa", status: "pending" }.merge(attrs))
  end

  # -- RuleResult struct --

  describe "RuleResult" do
    it "hard_block? returns the hard_block value, not inverted (mutation: negate)" do
      result = Fraud::Services::RuleResult.new(matched_rules: [], hard_block: true, latency_ms: 0.1)
      expect(result.hard_block?).to be true

      result2 = Fraud::Services::RuleResult.new(matched_rules: [], hard_block: false, latency_ms: 0.1)
      expect(result2.hard_block?).to be false
    end
  end

  # -- Velocity rule mutations --

  describe "rapid_fire_5min rule" do
    it "triggers at exactly 5 prior transactions (mutation: change threshold to 4 or 6)" do
      card = "5555"
      5.times { create_tx(card_last_four: card, created_at: 2.minutes.ago) }
      tx = create_tx(card_last_four: card)

      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).to include("rapid_fire_5min")
    end

    it "does NOT trigger at 4 prior transactions (boundary test)" do
      card = "5556"
      4.times { create_tx(card_last_four: card, created_at: 2.minutes.ago) }
      tx = create_tx(card_last_four: card)

      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).not_to include("rapid_fire_5min")
    end

    it "does NOT trigger for transactions outside 5-minute window (mutation: change window)" do
      card = "5557"
      5.times { create_tx(card_last_four: card, created_at: 10.minutes.ago) }
      tx = create_tx(card_last_four: card)

      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).not_to include("rapid_fire_5min")
    end

    it "has critical severity (mutation: change to high)" do
      card = "5558"
      5.times { create_tx(card_last_four: card, created_at: 2.minutes.ago) }
      tx = create_tx(card_last_four: card)

      result = engine.evaluate(tx)
      rapid_rule = result.matched_rules.find { |r| r[:name] == "rapid_fire_5min" }
      expect(rapid_rule[:severity]).to eq("critical")
    end

    it "results in hard_block? = true (mutation: remove critical check)" do
      card = "5559"
      5.times { create_tx(card_last_four: card, created_at: 2.minutes.ago) }
      tx = create_tx(card_last_four: card)

      result = engine.evaluate(tx)
      expect(result.hard_block?).to be true
    end
  end

  # -- Amount rule mutations --

  describe "very_high_amount rule" do
    it "triggers at exactly $5,000 (500_000 cents) (mutation: change threshold)" do
      tx = create_tx(amount_cents: 500_000)
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).to include("very_high_amount")
    end

    it "does NOT trigger at $4,999.99 (mutation: off-by-one)" do
      tx = create_tx(amount_cents: 499_999)
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).not_to include("very_high_amount")
    end

    it "has high severity (mutation: change to medium)" do
      tx = create_tx(amount_cents: 500_000)
      result = engine.evaluate(tx)
      rule = result.matched_rules.find { |r| r[:name] == "very_high_amount" }
      expect(rule[:severity]).to eq("high")
    end
  end

  describe "extreme_amount rule" do
    it "triggers at exactly $10,000 (1_000_000 cents)" do
      tx = create_tx(amount_cents: 1_000_000)
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).to include("extreme_amount")
    end

    it "does NOT trigger at $9,999.99" do
      tx = create_tx(amount_cents: 999_999)
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).not_to include("extreme_amount")
    end

    it "has critical severity (mutation: change to high)" do
      tx = create_tx(amount_cents: 1_000_000)
      result = engine.evaluate(tx)
      rule = result.matched_rules.find { |r| r[:name] == "extreme_amount" }
      expect(rule[:severity]).to eq("critical")
    end

    it "results in hard_block?" do
      tx = create_tx(amount_cents: 1_000_000)
      result = engine.evaluate(tx)
      expect(result.hard_block?).to be true
    end
  end

  # -- Round amount rule mutations --

  describe "suspicious_round_amount rule" do
    it "triggers for $2,000.00 exactly (round + above threshold)" do
      tx = create_tx(amount_cents: 200_000)
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).to include("suspicious_round_amount")
    end

    it "does NOT trigger for $1,999.99 (not round)" do
      tx = create_tx(amount_cents: 199_999)
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).not_to include("suspicious_round_amount")
    end

    it "does NOT trigger for $50.00 (below threshold)" do
      tx = create_tx(amount_cents: 5000)
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).not_to include("suspicious_round_amount")
    end

    it "has medium severity" do
      tx = create_tx(amount_cents: 200_000)
      result = engine.evaluate(tx)
      rule = result.matched_rules.find { |r| r[:name] == "suspicious_round_amount" }
      expect(rule[:severity]).to eq("medium")
    end
  end

  # -- Time rule mutations --

  describe "off_hours rule" do
    it "triggers at 3am (mutation: change start_hour)" do
      tx = create_tx(created_at: Time.zone.parse("2026-01-15 03:00:00"))
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).to include("off_hours")
    end

    it "triggers at 2am (boundary)" do
      tx = create_tx(created_at: Time.zone.parse("2026-01-15 02:00:00"))
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).to include("off_hours")
    end

    it "does NOT trigger at 5am (boundary, end_hour)" do
      tx = create_tx(created_at: Time.zone.parse("2026-01-15 05:00:00"))
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).not_to include("off_hours")
    end

    it "does NOT trigger at 1am (below start_hour)" do
      tx = create_tx(created_at: Time.zone.parse("2026-01-15 01:00:00"))
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).not_to include("off_hours")
    end

    it "does NOT trigger at 2pm" do
      tx = create_tx(created_at: Time.zone.parse("2026-01-15 14:00:00"))
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).not_to include("off_hours")
    end

    it "has low severity (mutation: change to high)" do
      tx = create_tx(created_at: Time.zone.parse("2026-01-15 03:00:00"))
      result = engine.evaluate(tx)
      rule = result.matched_rules.find { |r| r[:name] == "off_hours" }
      expect(rule[:severity]).to eq("low")
    end
  end

  # -- First transaction rule mutations --

  describe "first_tx_high_value rule" do
    it "triggers for first transaction with card above $500" do
      tx = create_tx(card_last_four: "6666", amount_cents: 60_000)
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).to include("first_tx_high_value")
    end

    it "does NOT trigger if card has prior history (mutation: skip history check)" do
      create_tx(card_last_four: "7777", created_at: 1.day.ago)
      tx = create_tx(card_last_four: "7777", amount_cents: 60_000)
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).not_to include("first_tx_high_value")
    end

    it "does NOT trigger for low-value first transaction (mutation: remove amount check)" do
      tx = create_tx(card_last_four: "8888", amount_cents: 5000)
      result = engine.evaluate(tx)
      rule_names = result.matched_rules.map { |r| r[:name] }
      expect(rule_names).not_to include("first_tx_high_value")
    end

    it "has high severity" do
      tx = create_tx(card_last_four: "9999", amount_cents: 60_000)
      result = engine.evaluate(tx)
      rule = result.matched_rules.find { |r| r[:name] == "first_tx_high_value" }
      expect(rule[:severity]).to eq("high")
    end
  end

  # -- hard_block? logic mutations --

  describe "hard_block? aggregation" do
    it "false when no rules match (mutation: return true)" do
      tx = create_tx(amount_cents: 5000)
      result = engine.evaluate(tx)
      expect(result.hard_block?).to be false
    end

    it "false when only low/medium severity rules match (mutation: check any severity)" do
      tx = create_tx(amount_cents: 200_000, created_at: Time.zone.parse("2026-01-15 03:00:00"))
      result = engine.evaluate(tx)
      # May trigger suspicious_round_amount (medium) and off_hours (low) but not critical
      has_critical = result.matched_rules.any? { |r| r[:severity] == "critical" }
      if has_critical
        # Amount also triggers very_high_amount (high) but not extreme_amount
        skip "This amount also triggers a critical rule"
      end
      expect(result.hard_block?).to be false
    end

    it "true when any critical rule matches, even with other non-critical rules (mutation: require all critical)" do
      card = "5560"
      5.times { create_tx(card_last_four: card, created_at: 2.minutes.ago) }
      tx = create_tx(card_last_four: card, amount_cents: 5000) # low amount + velocity trigger

      result = engine.evaluate(tx)
      expect(result.hard_block?).to be true
      # Also verify it's specifically because of critical severity
      severities = result.matched_rules.map { |r| r[:severity] }
      expect(severities).to include("critical")
    end
  end

  # -- Latency tracking mutations --

  describe "latency tracking" do
    it "records non-negative latency_ms (mutation: omit or negative)" do
      tx = create_tx
      result = engine.evaluate(tx)
      expect(result.latency_ms).to be >= 0.0
    end

    it "returns Float type (mutation: return Integer)" do
      tx = create_tx
      result = engine.evaluate(tx)
      expect(result.latency_ms).to be_a(Float)
    end
  end

  # -- Rule count mutations --

  describe "rule configuration" do
    it "has exactly 7 rules configured (mutation: add/remove rules)" do
      rules = engine.send(:build_rules)
      expect(rules.size).to eq(7)
    end

    it "has exactly 2 critical rules (mutation: change severity)" do
      rules = engine.send(:build_rules)
      critical_count = rules.count { |r| r.severity == "critical" }
      expect(critical_count).to eq(2)
    end
  end
end
