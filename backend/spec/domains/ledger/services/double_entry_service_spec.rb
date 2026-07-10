require "rails_helper"

RSpec.describe Ledger::Services::DoubleEntryService do
  let(:service) { described_class.new }
  let(:merchant) { create(:merchant, fee_percentage: 2.9, fee_fixed_cents: 30) }

  def create_transaction(amount_cents: 10_000, **attrs)
    create(:transaction, merchant: merchant, amount_cents: amount_cents, **attrs)
  end

  describe "#record_authorization" do
    it "creates debit and credit entries" do
      txn = create_transaction

      expect { service.record_authorization(transaction: txn) }
        .to change(LedgerEntry, :count).by(2)
    end

    it "debits settlement and credits processing" do
      txn = create_transaction(amount_cents: 5000)
      service.record_authorization(transaction: txn)

      settlement = Account.find_by(scope: "settlement", merchant: nil)
      processing = Account.find_by(scope: "processing", merchant: merchant)

      expect(settlement.balance_cents).to eq(-5000)
      expect(processing.balance_cents).to eq(5000)
    end

    it "maintains ledger balance after authorization" do
      txn = create_transaction
      service.record_authorization(transaction: txn)

      expect(service.verify_balance_integrity!).to eq(true)
    end
  end

  describe "#record_capture" do
    it "splits into net and fee" do
      txn = create_transaction(amount_cents: 10_000)
      service.record_authorization(transaction: txn)
      service.record_capture(transaction: txn)

      available = Account.find_by(scope: "available", merchant: merchant)
      fees = Account.find_by(scope: "fees_collected", merchant: nil)
      processing = Account.find_by(scope: "processing", merchant: merchant)

      expect(available.balance_cents).to eq(txn.net_cents)
      expect(fees.balance_cents).to eq(txn.fee_cents)
      expect(processing.balance_cents).to eq(0)
      expect(txn.fee_cents + txn.net_cents).to eq(10_000)
    end

    it "maintains ledger balance after capture" do
      txn = create_transaction
      service.record_authorization(transaction: txn)
      service.record_capture(transaction: txn)

      expect(service.verify_balance_integrity!).to eq(true)
    end
  end

  describe "#record_refund" do
    let(:txn) { create_transaction(amount_cents: 10_000) }

    before do
      service.record_authorization(transaction: txn)
      service.record_capture(transaction: txn)
    end

    it "moves funds from available back to settlement" do
      service.record_refund(transaction: txn)

      available = Account.find_by(scope: "available", merchant: merchant)
      expect(available.balance_cents).to eq(0)
    end

    it "supports partial refund" do
      service.record_refund(transaction: txn, amount_cents: 3000)

      available = Account.find_by(scope: "available", merchant: merchant)
      expect(available.balance_cents).to eq(txn.net_cents - 3000)
    end

    it "maintains ledger balance after refund" do
      service.record_refund(transaction: txn)
      expect(service.verify_balance_integrity!).to eq(true)
    end

    it "rejects zero amount refund" do
      expect {
        service.record_refund(transaction: txn, amount_cents: 0)
      }.to raise_error(ArgumentError)
    end

    it "rejects negative amount refund" do
      expect {
        service.record_refund(transaction: txn, amount_cents: -100)
      }.to raise_error(ArgumentError)
    end
  end

  describe "#verify_balance_integrity!" do
    it "passes on empty ledger" do
      expect(service.verify_balance_integrity!).to eq(true)
    end

    it "passes after multiple transactions" do
      3.times do
        txn = create_transaction(amount_cents: rand(100..100_000))
        service.record_authorization(transaction: txn)
        service.record_capture(transaction: txn)
      end

      expect(service.verify_balance_integrity!).to eq(true)
    end

    it "passes after authorize + capture + refund cycle" do
      txn = create_transaction(amount_cents: 50_000)
      service.record_authorization(transaction: txn)
      service.record_capture(transaction: txn)
      service.record_refund(transaction: txn)

      expect(service.verify_balance_integrity!).to eq(true)
    end
  end

  describe "fee calculation accuracy" do
    it "correctly calculates Stripe-style fee (2.9% + 30 cents)" do
      txn = create_transaction(amount_cents: 10_000)

      expected_percentage = (10_000 * 2.9 / 100.0).ceil
      expected_fee = expected_percentage + 30
      expected_net = 10_000 - expected_fee

      expect(txn.fee_cents).to eq(expected_fee)
      expect(txn.net_cents).to eq(expected_net)
      expect(txn.fee_cents + txn.net_cents).to eq(10_000)
    end

    it "never has floating point errors in fee calculation" do
      # Minimum $0.50 (50 cents) enforced by Transaction::MINIMUM_AMOUNT_CENTS
      [50, 99, 100, 333, 1000, 9999, 100_000, 999_999].each do |amount|
        txn = create_transaction(amount_cents: amount)
        expect(txn.fee_cents).to be_a(Integer)
        expect(txn.net_cents).to be_a(Integer)
        expect(txn.fee_cents + txn.net_cents).to eq(amount),
          "Fee split failed for amount #{amount}: fee=#{txn.fee_cents}, net=#{txn.net_cents}"
      end
    end

    it "rejects transactions below minimum amount" do
      expect {
        create_transaction(amount_cents: 1)
      }.to raise_error(ActiveRecord::RecordInvalid, /Amount cents/)
    end
  end

  describe "allowed transfers validation" do
    it "rejects unknown transfer codes" do
      txn = create_transaction
      expect {
        service.send(:transfer,
          amount_cents: 100, currency: "USD",
          from_scope: :settlement, from_type: :asset,
          to_scope: :processing, to_type: :asset,
          merchant: merchant, code: :fake_transfer,
          transaction: txn)
      }.to raise_error(described_class::InvalidTransferError, /Unknown transfer code/)
    end
  end

  describe "concurrent access safety" do
    it "handles concurrent authorizations without double-booking" do
      txns = Array.new(5) { create_transaction(amount_cents: 1000) }

      threads = txns.map do |txn|
        Thread.new { service.record_authorization(transaction: txn) }
      end
      threads.each(&:join)

      expect(LedgerEntry.count).to eq(10)
      expect(service.verify_balance_integrity!).to eq(true)
    end
  end
end
