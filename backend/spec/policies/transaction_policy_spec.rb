require "rails_helper"

RSpec.describe TransactionPolicy do
  let(:merchant_a) { create(:merchant) }
  let(:merchant_b) { create(:merchant) }
  let(:admin) { create(:user, role: "admin", merchant: merchant_a) }
  let(:manager_a) { create(:user, role: "manager", merchant: merchant_a) }
  let(:viewer_a) { create(:user, role: "viewer", merchant: merchant_a) }
  let(:manager_b) { create(:user, role: "manager", merchant: merchant_b) }
  let(:transaction_a) { create(:transaction, merchant: merchant_a) }
  let(:transaction_b) { create(:transaction, merchant: merchant_b) }

  def policy(record, user:)
    described_class.new(record, user: user, merchant: user.merchant)
  end

  describe "#show?" do
    it "allows admin to view any transaction" do
      expect(policy(transaction_a, user: admin)).to be_show
      expect(policy(transaction_b, user: admin)).to be_show
    end

    it "allows merchant user to view own transactions" do
      expect(policy(transaction_a, user: manager_a)).to be_show
    end

    it "denies merchant user from viewing other merchant's transactions" do
      expect(policy(transaction_b, user: manager_a)).not_to be_show
    end
  end

  describe "#create?" do
    it "allows admin to create transactions" do
      expect(policy(transaction_a, user: admin)).to be_create
    end

    it "allows manager to create for own merchant" do
      expect(policy(transaction_a, user: manager_a)).to be_create
    end

    it "denies viewer from creating transactions" do
      expect(policy(transaction_a, user: viewer_a)).not_to be_create
    end

    it "denies manager from creating for other merchant" do
      expect(policy(transaction_b, user: manager_a)).not_to be_create
    end
  end

  describe "#refund?" do
    let(:captured_tx) { create(:transaction, merchant: merchant_a, status: "captured", captured_at: 1.day.ago) }

    it "allows admin to refund captured transactions" do
      expect(policy(captured_tx, user: admin)).to be_refund
    end

    it "allows manager to refund own merchant's captured transactions" do
      expect(policy(captured_tx, user: manager_a)).to be_refund
    end

    it "denies viewer from refunding" do
      expect(policy(captured_tx, user: viewer_a)).not_to be_refund
    end

    it "denies refund on non-refundable transactions" do
      pending_tx = create(:transaction, merchant: merchant_a, status: "pending")
      expect(policy(pending_tx, user: admin)).not_to be_refund
    end
  end

  describe "relation_scope" do
    before do
      transaction_a
      transaction_b
    end

    it "returns all transactions for admin" do
      scope = policy(Transaction, user: admin)
                .apply_scope(Transaction.all, type: :active_record_relation)
      expect(scope.count).to eq(Transaction.count)
    end

    it "scopes transactions to own merchant for non-admin" do
      scope = policy(Transaction, user: manager_a)
                .apply_scope(Transaction.all, type: :active_record_relation)
      expect(scope.pluck(:merchant_id).uniq).to eq([merchant_a.id])
    end
  end
end
