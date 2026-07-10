require "rails_helper"

RSpec.describe Payments::Sagas::PaymentLifecycleSaga do
  let(:merchant) { create(:merchant, :with_webhook) }
  let(:transaction) do
    create(:transaction,
      merchant: merchant,
      amount_cents: 10_000,
      status: "pending",
      card_last_four: "4242",
      card_brand: "visa",
      card_token: "4242424242424242"
    )
  end

  before do
    # Stub network simulator for authorization
    stub_request(:post, "http://localhost:4200/v1/authorize")
      .to_return(
        status: 200,
        body: {
          id: "auth_#{SecureRandom.hex(6)}",
          status: "approved",
          authorization_code: "AUTH_TEST",
          response_code: "00"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub network simulator for capture
    stub_request(:post, "http://localhost:4200/v1/capture")
      .to_return(
        status: 200,
        body: {
          id: "cap_#{SecureRandom.hex(6)}",
          status: "approved",
          response_code: "00"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub webhook delivery
    stub_request(:post, "https://example.com/webhooks")
      .to_return(status: 200)
  end

  describe "#perform — happy path" do
    it "processes payment through full lifecycle" do
      described_class.new.perform(transaction.id)

      transaction.reload
      expect(transaction.authorization_code).to be_present
      expect(transaction.fraud_score).to be_present
      expect(transaction.fraud_decision).to eq("pass")
    end

    it "creates ledger entries for authorization and capture" do
      described_class.new.perform(transaction.id)

      expect(LedgerEntry.count).to be >= 4 # auth debit/credit + capture debit/credit
    end

    it "maintains ledger integrity after full lifecycle" do
      described_class.new.perform(transaction.id)

      ledger = Ledger::Services::DoubleEntryService.new
      expect(ledger.verify_balance_integrity!).to eq(true)
    end

    it "publishes events to event store" do
      described_class.new.perform(transaction.id)

      stream = "Payment$#{transaction.id}"
      events = Rails.configuration.event_store.read.stream(stream).to_a

      event_types = events.map { |e| e.class.name.demodulize }
      expect(event_types).to include("PaymentInitiated", "PaymentAuthorized", "FraudCheckPassed", "PaymentCaptured")
    end

    it "advances saga_step through all steps" do
      described_class.new.perform(transaction.id)
      transaction.reload
      expect(transaction.saga_step).to eq(7) # All 7 steps
    end
  end

  describe "#perform — authorization decline" do
    before do
      stub_request(:post, "http://localhost:4200/v1/authorize")
        .to_return(
          status: 402,
          body: {
            id: "auth_dec",
            status: "declined",
            decline_reason: "insufficient_funds",
            response_code: "51"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "marks transaction as failed on authorization decline" do
      described_class.new.perform(transaction.id)

      transaction.reload
      expect(transaction.status).to eq("failed")
      expect(transaction.failure_reason).to include("declined")
    end

    it "maintains ledger integrity after decline" do
      described_class.new.perform(transaction.id)

      ledger = Ledger::Services::DoubleEntryService.new
      expect(ledger.verify_balance_integrity!).to eq(true)
    end
  end

  describe "#perform — network timeout with circuit breaker" do
    before do
      stub_request(:post, "http://localhost:4200/v1/authorize")
        .to_timeout
    end

    it "handles timeout gracefully" do
      described_class.new.perform(transaction.id)

      transaction.reload
      expect(transaction.status).to eq("failed")
      expect(transaction.failure_reason).to be_present
    end
  end

  describe "#perform — fraud block" do
    before do
      # Use extreme amount ($10,000+) to trigger critical rule → hard block
      transaction.update!(amount_cents: 1_000_000, card_last_four: "0001", card_token: "4111111111110001")
      transaction.update_columns(fee_cents: transaction.merchant.calculate_fee(1_000_000), net_cents: 1_000_000 - transaction.merchant.calculate_fee(1_000_000))

      # Void will be called as compensation
      stub_request(:post, "http://localhost:4200/v1/void")
        .to_return(
          status: 200,
          body: { id: "void_fraud", status: "voided" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "blocks fraudulent transaction" do
      described_class.new.perform(transaction.id)

      transaction.reload
      expect(transaction.status).to eq("failed")
      expect(transaction.failure_reason).to include("Fraud check failed")
    end
  end

  describe "#perform — compensation on failure" do
    before do
      # Auth succeeds but capture fails
      stub_request(:post, "http://localhost:4200/v1/capture")
        .to_return(
          status: 500,
          body: { status: "error", decline_reason: "processor_error" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "http://localhost:4200/v1/void")
        .to_return(
          status: 200,
          body: { id: "void_test", status: "voided" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "runs compensation steps on capture failure" do
      described_class.new.perform(transaction.id)

      transaction.reload
      expect(transaction.status).to eq("failed")

      # Void should have been called
      expect(WebMock).to have_requested(:post, "http://localhost:4200/v1/void")
    end

    it "maintains ledger integrity even after compensation" do
      described_class.new.perform(transaction.id)

      ledger = Ledger::Services::DoubleEntryService.new
      expect(ledger.verify_balance_integrity!).to eq(true)
    end
  end

  describe "#perform — resume from step" do
    it "resumes from a specific step index" do
      # First, run through step 0 and 1 only
      saga = described_class.new

      # Run validate + idempotency steps
      saga.perform(transaction.id, 0)
      transaction.reload

      # Verify transaction progressed
      expect(transaction.saga_step).to be >= 1
    end
  end

  describe "#perform — inactive merchant" do
    before do
      merchant.update!(status: "suspended")
    end

    it "rejects payment for inactive merchant" do
      described_class.new.perform(transaction.id)

      transaction.reload
      expect(transaction.status).to eq("failed")
      expect(transaction.failure_reason).to include("Merchant not active")
    end
  end
end
