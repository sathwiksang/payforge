require "rails_helper"

# Mutation-equivalent tests for Ledger::Services::DoubleEntryService
# These tests catch the exact mutations that mutant would generate:
# - Operator flips (==, >=, >, <=)
# - Removed return values
# - Swapped arguments
# - Removed nil checks
# - Removed method calls
# - Changed constants
RSpec.describe Ledger::Services::DoubleEntryService, "mutation coverage" do
  let(:service) { described_class.new }
  let(:merchant) { create(:merchant, fee_percentage: 2.9, fee_fixed_cents: 30) }

  def create_tx(amount_cents: 10_000, **attrs)
    create(:transaction, merchant: merchant, amount_cents: amount_cents, **attrs)
  end

  describe "#verify_balance_integrity!" do
    it "returns true (not nil) on balanced ledger" do
      result = service.verify_balance_integrity!
      expect(result).to eq(true)
      expect(result).not_to be_nil
    end

    it "raises when debits != credits (mutation: flip ==)" do
      txn = create_tx
      service.record_authorization(transaction: txn)
      # Manually create an orphan debit to break balance using a valid scope
      account = Account.find_or_create_for(scope: "reserve", account_type: "asset", currency: "USD", merchant: nil)
      LedgerEntry.create!(
        account: account,
        payment_transaction: txn,
        entry_type: "debit",
        amount_cents: 999,
        currency: "USD",
        correlation_id: SecureRandom.uuid
      )

      expect { service.verify_balance_integrity! }.to raise_error(RuntimeError, /CRITICAL.*Ledger imbalance/)
    end

    it "error message includes actual values (mutation: remove string interpolation)" do
      txn = create_tx
      service.record_authorization(transaction: txn)
      account = Account.find_or_create_for(scope: "reserve", account_type: "asset", currency: "USD", merchant: nil)
      LedgerEntry.create!(
        account: account, payment_transaction: txn,
        entry_type: "credit", amount_cents: 42,
        currency: "USD", correlation_id: SecureRandom.uuid
      )

      expect { service.verify_balance_integrity! }.to raise_error(RuntimeError, /Difference.*42/)
    end
  end

  describe "#record_authorization" do
    it "creates exactly 2 entries (mutation: off-by-one)" do
      txn = create_tx
      expect { service.record_authorization(transaction: txn) }.to change(LedgerEntry, :count).by(2)
    end

    it "uses the transaction amount, not some other value (mutation: swap args)" do
      txn = create_tx(amount_cents: 7777)
      service.record_authorization(transaction: txn)

      entries = LedgerEntry.where(payment_transaction: txn)
      expect(entries.pluck(:amount_cents)).to all(eq(7777))
    end

    it "debits settlement (not processing) — mutation: swap from/to" do
      txn = create_tx(amount_cents: 5000)
      service.record_authorization(transaction: txn)

      settlement = Account.find_by(scope: "settlement", merchant: nil)
      processing = Account.find_by(scope: "processing", merchant: merchant)

      # Settlement is debited (negative), processing is credited (positive)
      expect(settlement.balance_cents).to eq(-5000)
      expect(processing.balance_cents).to eq(5000)
    end

    it "uses the correct currency from transaction (mutation: hardcode 'USD')" do
      txn = create_tx(amount_cents: 5000, currency: "EUR")
      service.record_authorization(transaction: txn)

      entries = LedgerEntry.where(payment_transaction: txn)
      expect(entries.pluck(:currency)).to all(eq("EUR"))
    end

    it "creates entries with matching correlation_id (mutation: remove correlation)" do
      txn = create_tx
      service.record_authorization(transaction: txn)

      entries = LedgerEntry.where(payment_transaction: txn)
      correlation_ids = entries.pluck(:correlation_id).uniq
      expect(correlation_ids.size).to eq(1)
      expect(correlation_ids.first).to be_present
    end
  end

  describe "#record_capture" do
    let(:txn) { create_tx(amount_cents: 10_000) }

    before { service.record_authorization(transaction: txn) }

    it "creates exactly 4 entries (2 for net, 2 for fee) — mutation: missing fee transfer" do
      expect { service.record_capture(transaction: txn) }.to change(LedgerEntry, :count).by(4)
    end

    it "uses net_cents for merchant (mutation: use amount_cents)" do
      service.record_capture(transaction: txn)

      available = Account.find_by(scope: "available", merchant: merchant)
      expect(available.balance_cents).to eq(txn.net_cents)
      expect(available.balance_cents).not_to eq(txn.amount_cents)
    end

    it "uses fee_cents for platform (mutation: use net_cents)" do
      service.record_capture(transaction: txn)

      fees = Account.find_by(scope: "fees_collected", merchant: nil)
      expect(fees.balance_cents).to eq(txn.fee_cents)
      expect(fees.balance_cents).not_to eq(txn.net_cents)
    end

    it "zeroes out processing account (mutation: skip one transfer)" do
      service.record_capture(transaction: txn)

      processing = Account.find_by(scope: "processing", merchant: merchant)
      expect(processing.balance_cents).to eq(0)
    end

    it "fee + net == original amount (mutation: wrong split)" do
      service.record_capture(transaction: txn)

      available = Account.find_by(scope: "available", merchant: merchant)
      fees = Account.find_by(scope: "fees_collected", merchant: nil)

      expect(available.balance_cents + fees.balance_cents).to eq(10_000)
    end
  end

  describe "#record_refund" do
    let(:txn) { create_tx(amount_cents: 10_000) }

    before do
      service.record_authorization(transaction: txn)
      service.record_capture(transaction: txn)
    end

    it "defaults to full net_cents refund (mutation: use amount_cents)" do
      service.record_refund(transaction: txn)

      available = Account.find_by(scope: "available", merchant: merchant)
      expect(available.balance_cents).to eq(0)
    end

    it "partial refund only moves specified amount (mutation: ignore amount_cents arg)" do
      service.record_refund(transaction: txn, amount_cents: 3000)

      available = Account.find_by(scope: "available", merchant: merchant)
      expect(available.balance_cents).to eq(txn.net_cents - 3000)
    end

    it "raises on zero amount (mutation: remove guard)" do
      expect { service.record_refund(transaction: txn, amount_cents: 0) }.to raise_error(ArgumentError)
    end

    it "raises on negative amount (mutation: flip .positive? to .negative?)" do
      expect { service.record_refund(transaction: txn, amount_cents: -100) }.to raise_error(ArgumentError)
    end

    it "moves funds to settlement, not processing (mutation: swap to_scope)" do
      service.record_refund(transaction: txn, amount_cents: 3000)

      settlement = Account.find_by(scope: "settlement", merchant: nil)
      # Settlement was debited during auth, now credited during refund
      expect(settlement.balance_cents).to eq(-10_000 + 3000)
    end
  end

  describe "private #transfer validation" do
    it "rejects unknown transfer codes (mutation: remove validate_transfer!)" do
      txn = create_tx
      expect {
        service.send(:transfer,
          amount_cents: 100, currency: "USD",
          from_scope: :settlement, from_type: :asset,
          to_scope: :processing, to_type: :asset,
          merchant: merchant, code: :nonexistent_code,
          transaction: txn)
      }.to raise_error(described_class::InvalidTransferError, /Unknown transfer code/)
    end

    it "rejects mismatched account types (mutation: remove account type check)" do
      txn = create_tx
      expect {
        service.send(:transfer,
          amount_cents: 100, currency: "USD",
          from_scope: :settlement, from_type: :revenue,  # wrong type
          to_scope: :processing, to_type: :asset,
          merchant: merchant, code: :payment_authorized,
          transaction: txn)
      }.to raise_error(described_class::InvalidTransferError, /not allowed/)
    end

    it "rejects zero amount (mutation: remove positive check)" do
      txn = create_tx
      expect {
        service.send(:transfer,
          amount_cents: 0, currency: "USD",
          from_scope: :settlement, from_type: :asset,
          to_scope: :processing, to_type: :asset,
          merchant: merchant, code: :payment_authorized,
          transaction: txn)
      }.to raise_error(ArgumentError, /must be positive/)
    end
  end

  describe "ALLOWED_TRANSFERS constant (mutation: change keys/values)" do
    it "has all required transfer types" do
      expected = %i[payment_authorized payment_captured fee_extracted payment_refunded
                    fee_refunded dispute_opened dispute_resolved dispute_lost]
      expect(described_class::ALLOWED_TRANSFERS.keys).to match_array(expected)
    end

    it "payment_authorized transfers from settlement to processing" do
      spec = described_class::ALLOWED_TRANSFERS[:payment_authorized]
      expect(spec[:from]).to eq([:settlement, :asset])
      expect(spec[:to]).to eq([:processing, :asset])
    end

    it "payment_captured transfers from processing to available" do
      spec = described_class::ALLOWED_TRANSFERS[:payment_captured]
      expect(spec[:from]).to eq([:processing, :asset])
      expect(spec[:to]).to eq([:available, :asset])
    end

    it "fee_extracted transfers from processing to fees_collected" do
      spec = described_class::ALLOWED_TRANSFERS[:fee_extracted]
      expect(spec[:from]).to eq([:processing, :asset])
      expect(spec[:to]).to eq([:fees_collected, :revenue])
    end

    it "payment_refunded transfers from available to settlement" do
      spec = described_class::ALLOWED_TRANSFERS[:payment_refunded]
      expect(spec[:from]).to eq([:available, :asset])
      expect(spec[:to]).to eq([:settlement, :asset])
    end
  end

  describe "#platform_account? (mutation: change account list)" do
    it "settlement is a platform account" do
      expect(service.send(:platform_account?, :settlement)).to be true
    end

    it "fees_collected is a platform account" do
      expect(service.send(:platform_account?, :fees_collected)).to be true
    end

    it "available is NOT a platform account" do
      expect(service.send(:platform_account?, :available)).to be false
    end

    it "processing is NOT a platform account" do
      expect(service.send(:platform_account?, :processing)).to be false
    end
  end

  describe "dispute lifecycle (mutation: skip dispute methods)" do
    let(:txn) { create_tx(amount_cents: 10_000) }

    before do
      service.record_authorization(transaction: txn)
      service.record_capture(transaction: txn)
    end

    it "dispute_opened moves funds to reserve" do
      service.record_dispute_opened(transaction: txn)

      reserve = Account.find_by(scope: "reserve", merchant: merchant)
      available = Account.find_by(scope: "available", merchant: merchant)

      expect(reserve.balance_cents).to eq(txn.net_cents)
      expect(available.balance_cents).to eq(0)
    end

    it "dispute_resolved returns funds from reserve to available" do
      service.record_dispute_opened(transaction: txn)
      service.record_dispute_resolved(transaction: txn)

      reserve = Account.find_by(scope: "reserve", merchant: merchant)
      available = Account.find_by(scope: "available", merchant: merchant)

      expect(reserve.balance_cents).to eq(0)
      expect(available.balance_cents).to eq(txn.net_cents)
    end

    it "dispute_lost moves reserve to settlement" do
      service.record_dispute_opened(transaction: txn)
      service.record_dispute_lost(transaction: txn)

      reserve = Account.find_by(scope: "reserve", merchant: merchant)
      expect(reserve.balance_cents).to eq(0)
      expect(service.verify_balance_integrity!).to eq(true)
    end

    it "ledger stays balanced through full dispute lifecycle" do
      service.record_dispute_opened(transaction: txn)
      expect(service.verify_balance_integrity!).to eq(true)
      service.record_dispute_resolved(transaction: txn)
      expect(service.verify_balance_integrity!).to eq(true)
    end
  end
end
