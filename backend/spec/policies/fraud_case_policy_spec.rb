require "rails_helper"

RSpec.describe FraudCasePolicy do
  let(:merchant) { create(:merchant) }
  let(:other_merchant) { create(:merchant) }
  let(:admin) { create(:user, role: "admin", merchant: merchant) }
  let(:analyst) { create(:user, role: "analyst", merchant: merchant) }
  let(:viewer) { create(:user, role: "viewer", merchant: merchant) }
  let(:other_viewer) { create(:user, role: "viewer", merchant: other_merchant) }

  let(:transaction) { create(:transaction, merchant: merchant) }
  let(:fraud_case) do
    Fraud::Models::FraudCase.create!(
      payment_transaction: transaction,
      merchant: merchant,
      status: "open",
      priority: :high,
      risk_score: 0.85,
      decision: "block",
      model_used: "rule_engine"
    )
  end

  def policy(record, user:)
    described_class.new(record, user: user, merchant: user.merchant)
  end

  describe "#index?" do
    it "allows admin" do
      expect(policy(fraud_case, user: admin)).to be_index
    end

    it "allows analyst" do
      expect(policy(fraud_case, user: analyst)).to be_index
    end

    it "denies viewer" do
      expect(policy(fraud_case, user: viewer)).not_to be_index
    end
  end

  describe "#show?" do
    it "allows admin" do
      expect(policy(fraud_case, user: admin)).to be_show
    end

    it "allows analyst" do
      expect(policy(fraud_case, user: analyst)).to be_show
    end

    it "allows same-merchant viewer" do
      expect(policy(fraud_case, user: viewer)).to be_show
    end

    it "denies other-merchant viewer" do
      expect(policy(fraud_case, user: other_viewer)).not_to be_show
    end
  end

  describe "#resolve?" do
    it "allows admin to resolve" do
      expect(policy(fraud_case, user: admin)).to be_resolve
    end

    it "allows analyst to resolve" do
      expect(policy(fraud_case, user: analyst)).to be_resolve
    end

    it "denies viewer from resolving" do
      expect(policy(fraud_case, user: viewer)).not_to be_resolve
    end
  end

  describe "#escalate?" do
    it "allows only admin" do
      expect(policy(fraud_case, user: admin)).to be_escalate
      expect(policy(fraud_case, user: analyst)).not_to be_escalate
    end
  end
end
