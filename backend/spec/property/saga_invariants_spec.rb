require "rails_helper"
require "rantly/rspec_extensions"

RSpec.describe "Saga Invariants (Property-Based)", type: :model do
  let(:ledger_service) { Ledger::Services::DoubleEntryService.new }
  let(:merchant) { create(:merchant, fee_percentage: 2.9, fee_fixed_cents: 30) }

  before do
    stub_request(:post, /localhost:3201/).to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
  end

  describe "ledger balance invariant across full lifecycle" do
    it "debits == credits after any sequence of authorize + capture operations" do
      property_of {
        Rantly { range(Transaction::MINIMUM_AMOUNT_CENTS, 500_000) }
      }.check(50) { |amount|
        txn = create(:transaction, merchant: merchant, amount_cents: amount)
        ledger_service.record_authorization(transaction: txn)
        ledger_service.record_capture(transaction: txn)
        expect(ledger_service.verify_balance_integrity!).to eq(true)
      }
    end

    it "debits == credits after authorize + capture + full refund" do
      property_of {
        Rantly { range(Transaction::MINIMUM_AMOUNT_CENTS, 500_000) }
      }.check(30) { |amount|
        txn = create(:transaction, merchant: merchant, amount_cents: amount)
        ledger_service.record_authorization(transaction: txn)
        ledger_service.record_capture(transaction: txn)
        ledger_service.record_refund(transaction: txn)
        expect(ledger_service.verify_balance_integrity!).to eq(true)
      }
    end

    it "debits == credits after authorize + capture + partial refund" do
      property_of {
        Rantly {
          amount = range(Transaction::MINIMUM_AMOUNT_CENTS, 500_000)
          [amount, range(1, [amount / 2, 1].max)]
        }
      }.check(30) { |(amount, refund)|
        txn = create(:transaction, merchant: merchant, amount_cents: amount)
        ledger_service.record_authorization(transaction: txn)
        ledger_service.record_capture(transaction: txn)
        refund_amount = [refund, txn.net_cents].min
        next if refund_amount <= 0
        ledger_service.record_refund(transaction: txn, amount_cents: refund_amount)
        expect(ledger_service.verify_balance_integrity!).to eq(true)
      }
    end

    it "debits == credits after authorize + capture + dispute lifecycle" do
      property_of {
        Rantly { range(Transaction::MINIMUM_AMOUNT_CENTS, 500_000) }
      }.check(20) { |amount|
        txn = create(:transaction, merchant: merchant, amount_cents: amount)
        ledger_service.record_authorization(transaction: txn)
        ledger_service.record_capture(transaction: txn)
        ledger_service.record_dispute_opened(transaction: txn)
        expect(ledger_service.verify_balance_integrity!).to eq(true)
        ledger_service.record_dispute_resolved(transaction: txn)
        expect(ledger_service.verify_balance_integrity!).to eq(true)
      }
    end
  end

  describe "fee + net == amount invariant" do
    it "holds for all random amounts across random fee structures" do
      property_of {
        Rantly {
          amount = range(Transaction::MINIMUM_AMOUNT_CENTS, 1_000_000)
          fee_pct = range(0, 1000) / 100.0  # 0.00% to 10.00%
          fee_fixed = range(0, 100)
          [amount, fee_pct, fee_fixed]
        }
      }.check(100) { |(amount, fee_pct, fee_fixed)|
        custom_merchant = create(:merchant, fee_percentage: fee_pct, fee_fixed_cents: fee_fixed)
        txn = create(:transaction, merchant: custom_merchant, amount_cents: amount)

        expect(txn.fee_cents + txn.net_cents).to eq(amount),
          "Invariant violated: fee(#{txn.fee_cents}) + net(#{txn.net_cents}) != amount(#{amount}) " \
          "with fee_pct=#{fee_pct}%, fixed=#{fee_fixed}"
        expect(txn.fee_cents).to be >= 0
        expect(txn.fee_cents).to be_a(Integer)
        expect(txn.net_cents).to be_a(Integer)
      }
    end
  end

  describe "payment aggregate state machine invariant" do
    it "always reaches a valid terminal state from any random lifecycle" do
      property_of {
        Rantly {
          amount = range(Transaction::MINIMUM_AMOUNT_CENTS, 500_000)
          # Random lifecycle path: 0=full, 1=void-after-init, 2=void-after-auth, 3=fail-auth, 4=fail-fraud
          path = range(0, 4)
          [amount, path]
        }
      }.check(50) { |(amount, path)|
        agg = Payments::Aggregates::PaymentAggregate.new(SecureRandom.uuid)
        agg.initiate(
          merchant_id: SecureRandom.uuid,
          amount_cents: amount,
          currency: "USD",
          idempotency_key: SecureRandom.hex(16)
        )

        case path
        when 0 # full lifecycle
          agg.authorize(authorization_code: "A#{rand(10000..99999)}", network_response: { code: "00" })
          agg.pass_fraud_check(score: (rand * 0.5).round(4), explanation: {}, decision: "pass")
          agg.capture
          expect(agg.status).to eq(:captured)
          expect(agg.captured_amount_cents).to eq(amount)
        when 1 # void after initiation
          agg.void
          expect(agg.status).to eq(:voided)
        when 2 # void after authorization
          agg.authorize(authorization_code: "A#{rand(10000..99999)}", network_response: { code: "00" })
          agg.void
          expect(agg.status).to eq(:voided)
        when 3 # fail authorization
          agg.fail_authorization(reason: "declined", network_response: { code: "51" })
          expect(agg.status).to eq(:failed)
        when 4 # fail fraud check
          agg.authorize(authorization_code: "A#{rand(10000..99999)}", network_response: { code: "00" })
          agg.fail_fraud_check(score: 0.95, explanation: {}, matched_rules: ["velocity"])
          expect(agg.status).to eq(:blocked)
        end

        # All paths should produce events
        expect(agg.unpublished_events.to_a).not_to be_empty
      }
    end
  end
end
