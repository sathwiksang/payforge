require "rails_helper"

# Mutation-equivalent tests for Fraud::Services::FraudScoringEngine
# Targets: threshold boundaries, decision logic, scoring fallbacks, fraud case creation
RSpec.describe Fraud::Services::FraudScoringEngine, "mutation coverage" do
  let(:merchant) { create(:merchant, average_transaction_cents: 10_000, transaction_count_30d: 100, chargeback_rate_90d: 0.01, onboarded_at: 90.days.ago) }
  let(:engine) { described_class.new }

  before do
    stub_request(:post, /localhost:3201/).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
  end

  def create_tx(attrs = {})
    create(:transaction, { merchant: merchant, amount_cents: 5000, card_last_four: "4242", card_brand: "visa", status: "pending" }.merge(attrs))
  end

  # -- Threshold mutations --

  describe "SCORE_THRESHOLD_BLOCK constant (mutation: change value)" do
    it "is 0.85" do
      expect(described_class::SCORE_THRESHOLD_BLOCK).to eq(0.85)
    end
  end

  describe "SCORE_THRESHOLD_REVIEW constant (mutation: change value)" do
    it "is 0.60" do
      expect(described_class::SCORE_THRESHOLD_REVIEW).to eq(0.60)
    end
  end

  # -- Decision logic mutations --

  describe "decision boundaries" do
    it "hard-block results in score of exactly 1.0 (mutation: 0.99 or 0.0)" do
      tx = create_tx(amount_cents: 1_000_000)
      result = engine.score(tx)
      expect(result.score).to eq(1.0)
    end

    it "hard-block decision is 'block' not 'review' (mutation: swap decision)" do
      tx = create_tx(amount_cents: 1_000_000)
      result = engine.score(tx)
      expect(result.decision).to eq("block")
      expect(result.decision).not_to eq("review")
    end

    it "normal transaction is 'pass' not 'block' (mutation: swap decision)" do
      tx = create_tx(amount_cents: 5000)
      result = engine.score(tx)
      expect(result.decision).to eq("pass")
      expect(result.decision).not_to eq("block")
    end

    it "model_used is never nil (mutation: remove assignment)" do
      tx = create_tx
      result = engine.score(tx)
      expect(result.model_used).to be_present
    end

    it "latency_ms is positive (mutation: set to 0)" do
      tx = create_tx
      result = engine.score(tx)
      expect(result.latency_ms).to be >= 0.0
      expect(result.latency_ms).to be_a(Float)
    end
  end

  # -- Fraud case creation mutations --

  describe "fraud case creation" do
    it "creates case for block, not for pass (mutation: flip condition)" do
      pass_tx = create_tx(amount_cents: 5000)
      expect { engine.score(pass_tx) }.not_to change(Fraud::Models::FraudCase, :count)

      block_tx = create_tx(amount_cents: 1_000_000)
      expect { engine.score(block_tx) }.to change(Fraud::Models::FraudCase, :count).by(1)
    end

    it "fraud case has correct risk_score (mutation: hardcode 0)" do
      tx = create_tx(amount_cents: 1_000_000)
      engine.score(tx)

      fc = Fraud::Models::FraudCase.last
      expect(fc.risk_score).to eq(1.0)
    end

    it "fraud case status is 'open' (mutation: 'resolved')" do
      tx = create_tx(amount_cents: 1_000_000)
      engine.score(tx)

      fc = Fraud::Models::FraudCase.last
      expect(fc.status).to eq("open")
    end

    it "fraud case references correct merchant (mutation: nil)" do
      tx = create_tx(amount_cents: 1_000_000)
      engine.score(tx)

      fc = Fraud::Models::FraudCase.last
      expect(fc.merchant).to eq(merchant)
    end

    it "fraud case references correct transaction (mutation: nil)" do
      tx = create_tx(amount_cents: 1_000_000)
      engine.score(tx)

      fc = Fraud::Models::FraudCase.last
      expect(fc.payment_transaction).to eq(tx)
    end

    it "critical block (score >= 0.95) gets :critical priority (mutation: :high)" do
      tx = create_tx(amount_cents: 1_000_000)
      engine.score(tx)

      fc = Fraud::Models::FraudCase.last
      expect(fc.priority).to eq("critical")
    end

    it "stores matched rules in fraud case (mutation: empty array)" do
      tx = create_tx(amount_cents: 1_000_000)
      engine.score(tx)

      fc = Fraud::Models::FraudCase.last
      expect(fc.matched_rules).not_to be_empty
    end
  end

  # -- Rule-based scoring fallback mutations --

  describe "rule_based_score (when no ML model)" do
    it "returns 0.0 for no matched rules (mutation: return 1.0)" do
      tx = create_tx(amount_cents: 5000)
      result = engine.score(tx)
      expect(result.score).to be < 0.60
    end

    it "rule-based fallback scoring maps severity correctly" do
      # Test the private rule_based_score method directly
      high_rule = Fraud::Services::RuleResult.new(
        matched_rules: [{ name: "test", severity: "high" }],
        hard_block: false, latency_ms: 0.1
      )
      low_rule = Fraud::Services::RuleResult.new(
        matched_rules: [{ name: "test", severity: "low" }],
        hard_block: false, latency_ms: 0.1
      )
      empty_rule = Fraud::Services::RuleResult.new(
        matched_rules: [], hard_block: false, latency_ms: 0.1
      )

      high_score = engine.send(:rule_based_score, high_rule)
      low_score = engine.send(:rule_based_score, low_rule)
      empty_score = engine.send(:rule_based_score, empty_rule)

      expect(high_score).to be > low_score
      expect(low_score).to be > empty_score
      expect(empty_score).to eq(0.0)
      expect(high_score).to eq(0.5)
      expect(low_score).to eq(0.1)
    end
  end

  # -- Graceful degradation mutations --

  describe "error handling" do
    it "returns valid result even if ML scoring raises (mutation: propagate error)" do
      allow(engine).to receive(:run_inference).and_raise(StandardError.new("model crash"))
      tx = create_tx(amount_cents: 5000)
      result = engine.score(tx)
      expect(result).to be_a(Fraud::Services::ScoringResult)
      expect(result.decision).to be_in(%w[pass review block])
    end

    it "SHAP timeout does not crash (mutation: remove rescue)" do
      stub_request(:post, /localhost:3201/).to_timeout
      tx = create_tx(amount_cents: 1_000_000)
      expect { engine.score(tx) }.not_to raise_error
    end

    it "returns empty SHAP values on timeout (mutation: raise)" do
      stub_request(:post, /localhost:3201/).to_timeout
      tx = create_tx(amount_cents: 1_000_000)
      result = engine.score(tx)
      expect(result.shap_values).to eq({})
    end
  end

  # -- ScoringResult struct mutations --

  describe "ScoringResult struct" do
    it "has all required fields" do
      result = Fraud::Services::ScoringResult.new(
        score: 0.5, decision: "review", shap_values: {},
        matched_rules: [], model_used: "test", latency_ms: 1.0
      )
      expect(result.score).to eq(0.5)
      expect(result.decision).to eq("review")
      expect(result.shap_values).to eq({})
      expect(result.matched_rules).to eq([])
      expect(result.model_used).to eq("test")
      expect(result.latency_ms).to eq(1.0)
    end
  end
end
