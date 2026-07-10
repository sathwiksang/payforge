require "rails_helper"

RSpec.describe "Payment Lifecycle Integration", type: :integration do
  let(:merchant) { create(:merchant, :with_webhook) }
  let(:ledger) { Ledger::Services::DoubleEntryService.new }

  before do
    stub_request(:post, "https://example.com/webhooks")
      .to_return(status: 200)
  end

  def create_payment(amount_cents: 10_000, card_token: "4242424242424242", card_last_four: "4242")
    create(:transaction,
      merchant: merchant,
      amount_cents: amount_cents,
      status: "pending",
      card_last_four: card_last_four,
      card_brand: "visa",
      card_token: card_token
    )
  end

  describe "happy path: full lifecycle" do
    before do
      stub_request(:post, "http://localhost:4200/v1/authorize")
        .to_return(
          status: 200,
          body: {
            id: "auth_happy",
            status: "approved",
            authorization_code: "AUTH_HAPPY",
            response_code: "00"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "http://localhost:4200/v1/capture")
        .to_return(
          status: 200,
          body: { id: "cap_happy", status: "approved", response_code: "00" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "processes payment through initiate → authorize → fraud → capture → settle" do
      payment = create_payment(amount_cents: 50_000)
      Payments::Sagas::PaymentLifecycleSaga.new.perform(payment.id)

      payment.reload
      expect(payment.authorization_code).to be_present
      expect(payment.fraud_score).to be_present
      expect(payment.fraud_decision).to eq("pass")

      # Verify event stream
      stream = "Payment$#{payment.id}"
      events = Rails.configuration.event_store.read.stream(stream).to_a
      event_names = events.map { |e| e.class.name.demodulize }

      expect(event_names).to include(
        "PaymentInitiated",
        "PaymentAuthorized",
        "FraudCheckPassed",
        "PaymentCaptured"
      )

      # Verify ledger
      expect(ledger.verify_balance_integrity!).to eq(true)

      # Processing should be zero (authorized then captured)
      processing = Account.find_by(scope: "processing", merchant: merchant)
      expect(processing.balance_cents).to eq(0)

      # Available should have net amount
      available = Account.find_by(scope: "available", merchant: merchant)
      expect(available.balance_cents).to eq(payment.net_cents)

      # Fees should be collected
      fees = Account.find_by(scope: "fees_collected", merchant: nil)
      expect(fees.balance_cents).to eq(payment.fee_cents)
    end

    it "supports refund after capture" do
      payment = create_payment(amount_cents: 20_000)
      Payments::Sagas::PaymentLifecycleSaga.new.perform(payment.id)
      payment.reload

      # Refund using the repository pattern
      aggregate = Payments::Aggregates::PaymentAggregate.new(payment.id)
      repo = AggregateRoot::Repository.new(Rails.configuration.event_store)
      repo.load(aggregate, "Payment$#{payment.id}")

      aggregate.refund(amount_cents: payment.net_cents)
      repo.store(aggregate, "Payment$#{payment.id}")

      ledger.record_refund(transaction: payment)

      # Verify
      expect(ledger.verify_balance_integrity!).to eq(true)

      available = Account.find_by(scope: "available", merchant: merchant)
      expect(available.balance_cents).to eq(0)
    end

    it "supports partial refund" do
      payment = create_payment(amount_cents: 30_000)
      Payments::Sagas::PaymentLifecycleSaga.new.perform(payment.id)
      payment.reload

      partial_refund = 5000
      ledger.record_refund(transaction: payment, amount_cents: partial_refund)

      expect(ledger.verify_balance_integrity!).to eq(true)

      available = Account.find_by(scope: "available", merchant: merchant)
      expect(available.balance_cents).to eq(payment.net_cents - partial_refund)
    end
  end

  describe "network timeout with circuit breaker" do
    before do
      stub_request(:post, "http://localhost:4200/v1/authorize")
        .to_timeout
    end

    it "handles timeout and marks payment as failed" do
      payment = create_payment
      Payments::Sagas::PaymentLifecycleSaga.new.perform(payment.id)

      payment.reload
      expect(payment.status).to eq("failed")
      expect(payment.failure_reason).to be_present
      expect(ledger.verify_balance_integrity!).to eq(true)
    end
  end

  describe "fraud block with compensation" do
    before do
      stub_request(:post, "http://localhost:4200/v1/authorize")
        .to_return(
          status: 200,
          body: {
            id: "auth_fraud",
            status: "approved",
            authorization_code: "AUTH_FRAUD",
            response_code: "00"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "http://localhost:4200/v1/void")
        .to_return(
          status: 200,
          body: { id: "void_fraud", status: "voided" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "blocks known-bad card and compensates authorization" do
      payment = create_payment(amount_cents: 1_000_000, card_token: "4111111111110001", card_last_four: "0001")
      Payments::Sagas::PaymentLifecycleSaga.new.perform(payment.id)

      payment.reload
      expect(payment.status).to eq("failed")
      expect(payment.failure_reason).to include("Fraud check failed")

      # Void should have been called to compensate the authorization
      expect(WebMock).to have_requested(:post, "http://localhost:4200/v1/void")
      expect(ledger.verify_balance_integrity!).to eq(true)
    end
  end

  describe "idempotency" do
    before do
      stub_request(:post, "http://localhost:4200/v1/authorize")
        .to_return(
          status: 200,
          body: {
            id: "auth_idem",
            status: "approved",
            authorization_code: "AUTH_IDEM",
            response_code: "00"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "http://localhost:4200/v1/capture")
        .to_return(
          status: 200,
          body: { id: "cap_idem", status: "approved" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "prevents duplicate transactions with same idempotency key" do
      payment1 = create_payment
      Payments::Sagas::PaymentLifecycleSaga.new.perform(payment1.id)

      # Try to create another with same idempotency key
      payment2 = merchant.transactions.build(
        idempotency_key: payment1.idempotency_key,
        amount_cents: 5000,
        currency: "USD",
        card_last_four: "4242",
        card_brand: "visa",
        status: "pending"
      )

      # Should fail uniqueness validation
      expect(payment2).not_to be_valid
    end
  end

  describe "multiple payments maintain integrity" do
    before do
      stub_request(:post, "http://localhost:4200/v1/authorize")
        .to_return(
          status: 200,
          body: {
            id: "auth_multi",
            status: "approved",
            authorization_code: "AUTH_MULTI",
            response_code: "00"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "http://localhost:4200/v1/capture")
        .to_return(
          status: 200,
          body: { id: "cap_multi", status: "approved" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "processes multiple payments and maintains ledger integrity" do
      amounts = [5000, 10_000, 25_000, 50_000, 100_000]
      payments = amounts.map { |amt| create_payment(amount_cents: amt) }

      payments.each do |payment|
        Payments::Sagas::PaymentLifecycleSaga.new.perform(payment.id)
      end

      expect(ledger.verify_balance_integrity!).to eq(true)

      total_fees = payments.sum { |p| p.reload; p.fee_cents }
      total_net = payments.sum { |p| p.net_cents }

      fees_account = Account.find_by(scope: "fees_collected", merchant: nil)
      available_account = Account.find_by(scope: "available", merchant: merchant)

      expect(fees_account.balance_cents).to eq(total_fees)
      expect(available_account.balance_cents).to eq(total_net)
    end
  end
end
