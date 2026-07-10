module Payments
  module Aggregates
    class PaymentAggregate
      include AggregateRoot

      InvalidTransition = Class.new(StandardError)
      AlreadyProcessed = Class.new(StandardError)

      attr_reader :status, :amount_cents, :currency, :merchant_id,
                  :fraud_score, :authorization_code, :captured_amount_cents,
                  :refunded_amount_cents

      def initialize(id)
        @id = id
        @status = :new
        @amount_cents = nil
        @currency = nil
        @merchant_id = nil
        @fraud_score = nil
        @authorization_code = nil
        @captured_amount_cents = 0
        @refunded_amount_cents = 0
      end

      def initiate(merchant_id:, amount_cents:, currency:, idempotency_key:, **attrs)
        raise AlreadyProcessed, "Payment already initiated" if @status != :new

        apply(Events::PaymentInitiated.new(data: {
          transaction_id: @id,
          merchant_id: merchant_id,
          amount_cents: amount_cents,
          currency: currency,
          idempotency_key: idempotency_key,
          **attrs
        }))
      end

      def authorize(authorization_code:, network_response:)
        ensure_status!(:initiated, "authorize")

        apply(Events::PaymentAuthorized.new(data: {
          transaction_id: @id,
          authorization_code: authorization_code,
          network_response: network_response,
          authorized_at: Time.current
        }))
      end

      def fail_authorization(reason:, network_response:)
        ensure_status!(:initiated, "fail authorization")

        apply(Events::PaymentAuthorizationFailed.new(data: {
          transaction_id: @id,
          reason: reason,
          network_response: network_response
        }))
      end

      def pass_fraud_check(score:, explanation:, decision:)
        ensure_status!(:authorized, "pass fraud check")

        apply(Events::FraudCheckPassed.new(data: {
          transaction_id: @id,
          score: score,
          explanation: explanation,
          decision: decision
        }))
      end

      def fail_fraud_check(score:, explanation:, matched_rules:)
        ensure_status!(:authorized, "fail fraud check")

        apply(Events::FraudCheckFailed.new(data: {
          transaction_id: @id,
          score: score,
          explanation: explanation,
          matched_rules: matched_rules
        }))
      end

      def capture(amount_cents: nil)
        ensure_status!(:fraud_cleared, "capture")
        capture_amount = amount_cents || @amount_cents
        raise ArgumentError, "Capture amount (#{capture_amount}) exceeds authorization (#{@amount_cents})" if capture_amount > @amount_cents

        apply(Events::PaymentCaptured.new(data: {
          transaction_id: @id,
          amount_cents: capture_amount,
          captured_at: Time.current
        }))
      end

      def settle
        ensure_status!(:captured, "settle")

        apply(Events::PaymentSettled.new(data: {
          transaction_id: @id,
          settled_at: Time.current
        }))
      end

      def refund(amount_cents: nil)
        unless @status.in?([:captured, :settled])
          raise InvalidTransition, "Cannot refund from #{@status}"
        end

        refund_amount = amount_cents || @captured_amount_cents
        remaining = @captured_amount_cents - @refunded_amount_cents
        raise ArgumentError, "Refund amount (#{refund_amount}) exceeds remaining capturable (#{remaining})" if refund_amount > remaining

        event_class = refund_amount == remaining ?
          Events::PaymentRefunded : Events::PaymentPartiallyRefunded

        apply(event_class.new(data: {
          transaction_id: @id,
          amount_cents: refund_amount,
          refunded_at: Time.current
        }))
      end

      def void
        unless @status.in?([:initiated, :authorized, :fraud_cleared])
          raise InvalidTransition, "Cannot void from #{@status}"
        end

        apply(Events::PaymentVoided.new(data: {
          transaction_id: @id,
          voided_at: Time.current
        }))
      end

      on Events::PaymentInitiated do |event|
        @status = :initiated
        @amount_cents = event.data[:amount_cents]
        @currency = event.data[:currency]
        @merchant_id = event.data[:merchant_id]
      end

      on Events::PaymentAuthorized do |event|
        @status = :authorized
        @authorization_code = event.data[:authorization_code]
      end

      on Events::PaymentAuthorizationFailed do |_event|
        @status = :failed
      end

      on Events::FraudCheckPassed do |event|
        @status = :fraud_cleared
        @fraud_score = event.data[:score]
      end

      on Events::FraudCheckFailed do |event|
        @status = :blocked
        @fraud_score = event.data[:score]
      end

      on Events::PaymentCaptured do |event|
        @status = :captured
        @captured_amount_cents = event.data[:amount_cents]
      end

      on Events::PaymentSettled do |_event|
        @status = :settled
      end

      on Events::PaymentRefunded do |event|
        @status = :refunded
        @refunded_amount_cents += event.data[:amount_cents]
      end

      on Events::PaymentPartiallyRefunded do |event|
        @refunded_amount_cents += event.data[:amount_cents]
      end

      on Events::PaymentVoided do |_event|
        @status = :voided
      end

      private

      def ensure_status!(expected, action)
        unless @status == expected
          raise InvalidTransition, "Cannot #{action} from #{@status} (expected #{expected})"
        end
      end
    end
  end
end
