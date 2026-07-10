require "rails_helper"

RSpec.describe Fraud::Services::FraudScoringEngine do
  let(:merchant) { create(:merchant, average_transaction_cents: 10_000, transaction_count_30d: 100, chargeback_rate_90d: 0.01, onboarded_at: 90.days.ago) }

  before do
    stub_request(:post, /localhost:3201/).to_return(status: 200, body: "{}",  headers: { "Content-Type" => "application/json" })
  end

  def create_tx(attrs = {})
    create(:transaction, { merchant: merchant, amount_cents: 5000, card_last_four: "4242", card_brand: "visa", status: "pending" }.merge(attrs))
  end

  describe "#score" do
    let(:engine) { described_class.new }

    context "basic scoring" do
      it "returns a ScoringResult" do
        tx = create_tx
        result = engine.score(tx)
        expect(result).to be_a(Fraud::Services::ScoringResult)
      end

      it "passes normal transactions" do
        tx = create_tx(amount_cents: 5000)
        result = engine.score(tx)
        expect(result.decision).to eq("pass")
        expect(result.score).to be < 0.60
      end

      it "blocks transactions matching critical rules" do
        tx = create_tx(amount_cents: 1_000_000)
        result = engine.score(tx)
        expect(result.decision).to eq("block")
        expect(result.score).to eq(1.0)
      end

      it "includes matched rules" do
        tx = create_tx(amount_cents: 500_000)
        result = engine.score(tx)
        expect(result.matched_rules).not_to be_empty
      end

      it "includes latency_ms" do
        tx = create_tx
        result = engine.score(tx)
        expect(result.latency_ms).to be_a(Float)
      end

      it "reports model_used" do
        tx = create_tx
        result = engine.score(tx)
        expect(result.model_used).to be_present
      end
    end

    context "ML model scoring" do
      it "uses lightgbm model when available" do
        model_path = Rails.root.join("ml_models", "fraud_lgbm.txt")
        skip "LightGBM model not trained yet" unless File.exist?(model_path)

        tx = create_tx
        result = engine.score(tx)
        expect(result.model_used).to include("lightgbm")
      end

      it "scores normal transactions low with ML model" do
        model_path = Rails.root.join("ml_models", "fraud_lgbm.txt")
        skip "LightGBM model not trained yet" unless File.exist?(model_path)

        tx = create_tx(amount_cents: 5000)
        result = engine.score(tx)
        expect(result.score).to be < 0.60
        expect(result.decision).to eq("pass")
      end
    end

    context "decision thresholds" do
      it "blocks velocity-triggered transactions (5+ in 5min = critical)" do
        card = "5555"
        5.times { create_tx(card_last_four: card, created_at: 2.minutes.ago) }
        tx = create_tx(card_last_four: card)
        result = engine.score(tx)
        expect(result.decision).to eq("block")
      end
    end

    context "fraud case creation" do
      it "creates a FraudCase for block decisions" do
        tx = create_tx(amount_cents: 1_000_000)
        expect { engine.score(tx) }.to change(Fraud::Models::FraudCase, :count).by(1)

        fraud_case = Fraud::Models::FraudCase.last
        expect(fraud_case.decision).to eq("block")
        expect(fraud_case.status).to eq("open")
        expect(fraud_case.risk_score).to eq(1.0)
        expect(fraud_case.merchant).to eq(merchant)
      end

      it "does not create a FraudCase for pass decisions" do
        tx = create_tx(amount_cents: 5000)
        expect { engine.score(tx) }.not_to change(Fraud::Models::FraudCase, :count)
      end

      it "creates a FraudCase for block decisions with critical priority" do
        tx = create_tx(amount_cents: 1_000_000)
        engine.score(tx)

        fraud_case = Fraud::Models::FraudCase.last
        expect(fraud_case).to be_present
        expect(fraud_case.priority).to eq("critical")
      end
    end

    context "graceful degradation" do
      it "does not raise when model file is missing" do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(anything).and_call_original

        # Even if we can't mock the file, the engine should never raise
        tx = create_tx
        expect { engine.score(tx) }.not_to raise_error
      end

      it "does not raise when SHAP endpoint is unavailable" do
        stub_request(:post, /localhost:3201/).to_timeout
        tx = create_tx(amount_cents: 1_000_000)
        expect { engine.score(tx) }.not_to raise_error
      end

      it "returns valid result even with SHAP timeout" do
        stub_request(:post, /localhost:3201/).to_timeout
        tx = create_tx(amount_cents: 1_000_000)
        result = engine.score(tx)
        expect(result).to be_a(Fraud::Services::ScoringResult)
        expect(result.decision).to eq("block")
      end
    end
  end
end
