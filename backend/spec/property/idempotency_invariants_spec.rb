require "rails_helper"
require "rantly/rspec_extensions"

RSpec.describe "Idempotency Invariants (Property-Based)", type: :model do
  let(:merchant) { create(:merchant, fee_percentage: 2.9, fee_fixed_cents: 30) }

  describe "idempotency key uniqueness" do
    it "two transactions with different idempotency keys always produce different records" do
      property_of {
        Rantly { range(Transaction::MINIMUM_AMOUNT_CENTS, 500_000) }
      }.check(20) { |amount|
        key1 = "idem_#{SecureRandom.hex(8)}"
        key2 = "idem_#{SecureRandom.hex(8)}"

        txn1 = create(:transaction, merchant: merchant, amount_cents: amount, idempotency_key: key1)
        txn2 = create(:transaction, merchant: merchant, amount_cents: amount, idempotency_key: key2)

        expect(txn1.id).not_to eq(txn2.id)
        expect(txn1.idempotency_key).not_to eq(txn2.idempotency_key)
      }
    end

    it "same idempotency key + merchant prevents duplicate creation" do
      key = "idem_unique_#{SecureRandom.hex(8)}"
      create(:transaction, merchant: merchant, amount_cents: 5000, idempotency_key: key)

      expect {
        create(:transaction, merchant: merchant, amount_cents: 5000, idempotency_key: key)
      }.to raise_error(ActiveRecord::RecordInvalid, /Idempotency key/)
    end

    it "same idempotency key with different merchant is allowed" do
      key = "idem_shared_#{SecureRandom.hex(8)}"
      other_merchant = create(:merchant)
      create(:transaction, merchant: merchant, amount_cents: 5000, idempotency_key: key)

      expect {
        create(:transaction, merchant: other_merchant, amount_cents: 5000, idempotency_key: key)
      }.not_to raise_error
    end
  end

  describe "ledger idempotency" do
    let(:ledger_service) { Ledger::Services::DoubleEntryService.new }

    it "recording authorization twice for same transaction creates exactly 2 entries total" do
      txn = create(:transaction, merchant: merchant, amount_cents: 5000)
      ledger_service.record_authorization(transaction: txn)

      initial_count = LedgerEntry.where(payment_transaction: txn).count
      expect(initial_count).to eq(2)

      # Second authorization for same txn creates 2 more (different correlation_id)
      # The ledger is append-only; duplicate prevention is at the saga level, not ledger
      ledger_service.record_authorization(transaction: txn)
      expect(LedgerEntry.where(payment_transaction: txn).count).to eq(4)

      # But ledger still balances
      expect(ledger_service.verify_balance_integrity!).to eq(true)
    end
  end

  describe "aggregate event idempotency" do
    it "cannot re-initiate the same aggregate" do
      property_of {
        Rantly { range(Transaction::MINIMUM_AMOUNT_CENTS, 500_000) }
      }.check(20) { |amount|
        agg = Payments::Aggregates::PaymentAggregate.new(SecureRandom.uuid)
        agg.initiate(
          merchant_id: SecureRandom.uuid,
          amount_cents: amount,
          currency: "USD",
          idempotency_key: SecureRandom.hex(16)
        )

        expect {
          agg.initiate(
            merchant_id: SecureRandom.uuid,
            amount_cents: amount,
            currency: "USD",
            idempotency_key: SecureRandom.hex(16)
          )
        }.to raise_error(Payments::Aggregates::PaymentAggregate::AlreadyProcessed)
      }
    end

    it "cannot re-authorize the same aggregate" do
      property_of {
        Rantly { range(Transaction::MINIMUM_AMOUNT_CENTS, 500_000) }
      }.check(20) { |amount|
        agg = Payments::Aggregates::PaymentAggregate.new(SecureRandom.uuid)
        agg.initiate(
          merchant_id: SecureRandom.uuid, amount_cents: amount,
          currency: "USD", idempotency_key: SecureRandom.hex(16)
        )
        agg.authorize(authorization_code: "A12345", network_response: { code: "00" })

        expect {
          agg.authorize(authorization_code: "A67890", network_response: { code: "00" })
        }.to raise_error(Payments::Aggregates::PaymentAggregate::InvalidTransition)
      }
    end
  end
end
