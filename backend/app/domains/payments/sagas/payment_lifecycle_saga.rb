module Payments
  module Sagas
    class PaymentLifecycleSaga
      include Sidekiq::Job

      sidekiq_options queue: :payments, retry: 3

      class Result
        attr_reader :error

        def initialize(success:, error: nil)
          @success = success
          @error = error
        end

        def success?
          @success
        end

        def failure?
          !@success
        end

        def self.success
          new(success: true)
        end

        def self.failure(error)
          new(success: false, error: error)
        end
      end

      STEPS = %i[
        validate_request
        check_idempotency
        authorize_with_network
        score_fraud
        record_in_ledger
        capture_payment
        notify_merchant
      ].freeze

      COMPENSATIONS = {
        authorize_with_network: :void_authorization,
        record_in_ledger: :reverse_ledger_entry,
        capture_payment: :reverse_capture,
        notify_merchant: :send_failure_notification
      }.freeze

      def perform(transaction_id, step_index = 0)
        @transaction = Transaction.find(transaction_id)
        @aggregate = load_aggregate(transaction_id)

        STEPS[step_index..].each_with_index do |step, offset|
          current_index = step_index + offset

          result = execute_step(step)

          if result.failure?
            compensate(current_index, result.error)
            return
          end

          @transaction.update!(saga_step: current_index + 1)
        end

        finalize_settlement
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error("Saga: Transaction #{transaction_id} not found: #{e.message}")
      rescue => e
        Rails.logger.error("Saga error at step #{step_index}: #{e.message}")
        compensate(step_index, e.message) if @transaction
        raise
      end

      private

      def execute_step(step)
        send(step)
      end

      def validate_request
        if @transaction.amount_cents < Transaction::MINIMUM_AMOUNT_CENTS
          return Result.failure("Amount below minimum: #{@transaction.amount_cents}")
        end

        unless @transaction.merchant&.status == "active"
          return Result.failure("Merchant not active")
        end

        unless @transaction.status.in?(%w[pending initiated])
          return Result.failure("Transaction not in processable state: #{@transaction.status}")
        end

        @aggregate.initiate(
          merchant_id: @transaction.merchant_id,
          amount_cents: @transaction.amount_cents,
          currency: @transaction.currency,
          idempotency_key: @transaction.idempotency_key,
          card_last_four: @transaction.card_last_four,
          card_brand: @transaction.card_brand
        ) if @aggregate.status == :new

        store_aggregate(@aggregate)
        Result.success
      rescue => e
        Result.failure("Validation failed: #{e.message}")
      end

      def check_idempotency
        existing = Transaction.where(
          idempotency_key: @transaction.idempotency_key,
          merchant_id: @transaction.merchant_id
        ).where.not(id: @transaction.id).first

        if existing
          return Result.failure("Duplicate idempotency key: #{@transaction.idempotency_key}")
        end

        Result.success
      end

      def authorize_with_network
        gateway = Payments::Services::GatewayClient.new
        response = gateway.authorize(
          amount_cents: @transaction.amount_cents,
          currency: @transaction.currency,
          card_token: @transaction.card_token || @transaction.card_last_four,
          merchant_id: @transaction.merchant_id,
          idempotency_key: @transaction.idempotency_key
        )

        if response.success?
          @aggregate.authorize(
            authorization_code: response.authorization_code,
            network_response: response.to_h
          )
          store_aggregate(@aggregate)
          @transaction.update!(
            authorization_code: response.authorization_code,
            network_transaction_id: response.network_transaction_id
          )
          Result.success
        else
          @aggregate.fail_authorization(
            reason: response.decline_reason,
            network_response: response.to_h
          )
          store_aggregate(@aggregate)
          Result.failure("Authorization declined: #{response.decline_reason}")
        end
      end

      def score_fraud
        engine = Fraud::Services::FraudScoringEngine.new
        result = engine.score(@transaction)

        @transaction.update!(
          fraud_score: result.score,
          fraud_decision: result.decision
        )

        if result.decision == "block"
          @aggregate.fail_fraud_check(
            score: result.score,
            explanation: result.shap_values,
            matched_rules: result.matched_rules
          )
          store_aggregate(@aggregate)
          Result.failure("Fraud check failed: score #{result.score}")
        else
          @aggregate.pass_fraud_check(
            score: result.score,
            explanation: result.shap_values,
            decision: result.decision
          )
          store_aggregate(@aggregate)
          Result.success
        end
      end

      def record_in_ledger
        ledger = Ledger::Services::DoubleEntryService.new
        @transaction.reload
        ledger.record_authorization(transaction: @transaction)
        Result.success
      rescue => e
        Result.failure("Ledger recording failed: #{e.message}")
      end

      def capture_payment
        gateway = Payments::Services::GatewayClient.new
        response = gateway.capture(
          authorization_code: @transaction.authorization_code,
          amount_cents: @transaction.amount_cents,
          idempotency_key: "capture_#{@transaction.idempotency_key}"
        )

        if response.success?
          @aggregate.capture(amount_cents: @transaction.amount_cents)
          store_aggregate(@aggregate)

          ledger = Ledger::Services::DoubleEntryService.new
          @transaction.reload
          ledger.record_capture(transaction: @transaction)

          Result.success
        else
          Result.failure("Capture failed: #{response.decline_reason}")
        end
      end

      def notify_merchant
        if @transaction.merchant.webhook_url_ciphertext.present?
          Webhooks::Services::WebhookDeliveryService.new.deliver_payment_captured(@transaction)
        end
        Result.success
      rescue => e
        Rails.logger.warn("Webhook notification failed (non-critical): #{e.message}")
        Result.success
      end

      # --- Compensation ---

      def compensate(failed_step_index, reason)
        (failed_step_index - 1).downto(0) do |i|
          step = STEPS[i]
          compensation = COMPENSATIONS[step]
          next unless compensation

          begin
            send(compensation)
          rescue => e
            Rails.logger.error("COMPENSATION FAILED for #{step}: #{e.message}")
            FailedCompensation.create!(
              transaction: @transaction,
              step: step.to_s,
              compensation: compensation.to_s,
              error: e.message
            )
          end
        end

        @transaction.update!(status: "failed", failure_reason: reason)
      end

      def void_authorization
        return unless @transaction.authorization_code.present?

        gateway = Payments::Services::GatewayClient.new
        gateway.void(
          authorization_code: @transaction.authorization_code,
          idempotency_key: "void_#{@transaction.idempotency_key}"
        )
      end

      def reverse_ledger_entry
        ledger = Ledger::Services::DoubleEntryService.new
        @transaction.reload

        processing_account = Account.find_by(
          scope: "processing",
          merchant: @transaction.merchant,
          currency: @transaction.currency
        )
        return unless processing_account&.balance_cents&.positive?

        ledger.record_refund(transaction: @transaction, amount_cents: processing_account.balance_cents)
      rescue => e
        Rails.logger.error("Reverse ledger failed: #{e.message}")
      end

      def reverse_capture
        # Capture reversal is handled via refund flow
        reverse_ledger_entry
      end

      def send_failure_notification
        if @transaction.merchant.webhook_url_ciphertext.present?
          Webhooks::Services::WebhookDeliveryService.new.deliver_payment_failed(@transaction)
        end
      rescue => e
        Rails.logger.warn("Failure notification failed: #{e.message}")
      end

      def finalize_settlement
        @aggregate.settle if @aggregate.status == :captured
        store_aggregate(@aggregate)
        @transaction.reload
        @transaction.update!(settled_at: Time.current) if @transaction.status == "settled"
      rescue => e
        Rails.logger.warn("Settlement finalization note: #{e.message}")
      end

      # --- Event Store Helpers ---

      def load_aggregate(id)
        aggregate = Payments::Aggregates::PaymentAggregate.new(id)
        repository.load(aggregate, "Payment$#{id}")
        aggregate
      rescue AggregateRoot::Repository::InvalidEventClass,
             RubyEventStore::ExpectedVersion::Error
        aggregate
      end

      def store_aggregate(aggregate)
        return if aggregate.unpublished_events.to_a.empty?

        repository.store(aggregate, "Payment$#{@transaction.id}")
      end

      def repository
        @repository ||= AggregateRoot::Repository.new(Rails.configuration.event_store)
      end
    end
  end
end
