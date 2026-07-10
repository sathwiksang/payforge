require "rails_helper"

RSpec.describe "Ledger Invariants (Property-Based)", type: :model do
  let(:service) { Ledger::Services::DoubleEntryService.new }
  let(:merchant) { create(:merchant, fee_percentage: 2.9, fee_fixed_cents: 30) }

  def random_amount
    rand(Transaction::MINIMUM_AMOUNT_CENTS..1_000_000)
  end

  describe "fundamental accounting equation: debits == credits" do
    it "holds after any sequence of authorizations" do
      50.times do
        txn = create(:transaction, merchant: merchant, amount_cents: random_amount)
        service.record_authorization(transaction: txn)
      end

      expect(service.verify_balance_integrity!).to eq(true)
    end

    it "holds after any sequence of authorize + capture" do
      50.times do
        txn = create(:transaction, merchant: merchant, amount_cents: random_amount)
        service.record_authorization(transaction: txn)
        service.record_capture(transaction: txn)
      end

      expect(service.verify_balance_integrity!).to eq(true)
    end

    it "holds after mixed authorize, capture, and refund operations" do
      transactions = Array.new(30) do
        create(:transaction, merchant: merchant, amount_cents: random_amount)
      end

      transactions.each do |txn|
        service.record_authorization(transaction: txn)
        service.record_capture(transaction: txn)
      end

      transactions.sample(10).each do |txn|
        refund_amount = rand(1..txn.net_cents)
        service.record_refund(transaction: txn, amount_cents: refund_amount)
      end

      expect(service.verify_balance_integrity!).to eq(true)
    end

    it "holds with randomized fee structures" do
      20.times do
        custom_merchant = create(:merchant,
          fee_percentage: rand(0.0..10.0).round(2),
          fee_fixed_cents: rand(0..100)
        )

        txn = create(:transaction, merchant: custom_merchant, amount_cents: random_amount)
        service.record_authorization(transaction: txn)
        service.record_capture(transaction: txn)
      end

      expect(service.verify_balance_integrity!).to eq(true)
    end
  end

  describe "fee + net always equals amount" do
    it "holds for 100 random amounts" do
      100.times do
        amount = random_amount
        txn = create(:transaction, merchant: merchant, amount_cents: amount)

        expect(txn.fee_cents + txn.net_cents).to eq(amount),
          "Invariant violated: fee(#{txn.fee_cents}) + net(#{txn.net_cents}) != amount(#{amount})"
      end
    end

    it "holds for edge case amounts" do
      # Amounts must be >= Transaction::MINIMUM_AMOUNT_CENTS (50)
      [50, 51, 99, 100, 999, 1000, 10_000, 100_000, 999_999, 1_000_000].each do |amount|
        txn = create(:transaction, merchant: merchant, amount_cents: amount)

        expect(txn.fee_cents + txn.net_cents).to eq(amount),
          "Edge case failed for amount #{amount}"
        expect(txn.fee_cents).to be >= 0
        expect(txn.net_cents).to be >= 0 if amount > merchant.fee_fixed_cents
      end
    end
  end

  describe "refund never exceeds captured amount" do
    it "holds across random partial refund sequences" do
      20.times do
        txn = create(:transaction, merchant: merchant, amount_cents: random_amount)
        service.record_authorization(transaction: txn)
        service.record_capture(transaction: txn)

        total_refunded = 0
        rand(1..5).times do
          remaining = txn.net_cents - total_refunded
          break if remaining <= 0

          refund_amount = rand(1..[remaining, 1].max)
          service.record_refund(transaction: txn, amount_cents: refund_amount)
          total_refunded += refund_amount
        end

        expect(total_refunded).to be <= txn.net_cents,
          "Refund exceeded capture: refunded=#{total_refunded}, net=#{txn.net_cents}"
      end

      expect(service.verify_balance_integrity!).to eq(true)
    end
  end

  describe "account balance consistency" do
    it "processing account returns to zero after full authorize + capture" do
      10.times do
        txn = create(:transaction, merchant: merchant, amount_cents: random_amount)
        service.record_authorization(transaction: txn)
        service.record_capture(transaction: txn)
      end

      processing = Account.find_by(scope: "processing", merchant: merchant)
      expect(processing.balance_cents).to eq(0),
        "Processing account not zero after all captures: #{processing.balance_cents}"
    end

    it "available account accumulates net amounts correctly" do
      amounts = Array.new(10) { random_amount }
      transactions = amounts.map do |amt|
        create(:transaction, merchant: merchant, amount_cents: amt)
      end

      transactions.each do |txn|
        service.record_authorization(transaction: txn)
        service.record_capture(transaction: txn)
      end

      expected_available = transactions.sum(&:net_cents)
      available = Account.find_by(scope: "available", merchant: merchant)
      expect(available.balance_cents).to eq(expected_available)
    end

    it "fees account accumulates fee amounts correctly" do
      amounts = Array.new(10) { random_amount }
      transactions = amounts.map do |amt|
        create(:transaction, merchant: merchant, amount_cents: amt)
      end

      transactions.each do |txn|
        service.record_authorization(transaction: txn)
        service.record_capture(transaction: txn)
      end

      expected_fees = transactions.sum(&:fee_cents)
      fees = Account.find_by(scope: "fees_collected", merchant: nil)
      expect(fees.balance_cents).to eq(expected_fees)
    end
  end

  describe "all ledger entries have matching pairs" do
    it "every debit has a corresponding credit with same correlation_id" do
      5.times do
        txn = create(:transaction, merchant: merchant, amount_cents: random_amount)
        service.record_authorization(transaction: txn)
        service.record_capture(transaction: txn)
      end

      correlation_ids = LedgerEntry.distinct.pluck(:correlation_id)
      correlation_ids.each do |cid|
        entries = LedgerEntry.where(correlation_id: cid)
        debits = entries.where(entry_type: "debit").sum(:amount_cents)
        credits = entries.where(entry_type: "credit").sum(:amount_cents)

        expect(debits).to eq(credits),
          "Correlation #{cid}: debits(#{debits}) != credits(#{credits})"
      end
    end
  end
end
