module Payments
  module ReadModels
    class TransactionReadModel
      def call(event)
        case event
        when Events::PaymentInitiated
          handle_initiated(event)
        when Events::PaymentAuthorized
          handle_authorized(event)
        when Events::PaymentAuthorizationFailed
          handle_auth_failed(event)
        when Events::FraudCheckPassed
          handle_fraud_passed(event)
        when Events::FraudCheckFailed
          handle_fraud_failed(event)
        when Events::PaymentCaptured
          handle_captured(event)
        when Events::PaymentSettled
          handle_settled(event)
        when Events::PaymentFailed
          handle_failed(event)
        when Events::PaymentRefunded
          handle_refunded(event)
        when Events::PaymentPartiallyRefunded
          handle_partially_refunded(event)
        when Events::PaymentVoided
          handle_voided(event)
        end
      end

      private

      def handle_initiated(event)
        data = event.data
        txn = Transaction.find_by(id: data[:transaction_id])

        if txn
          txn.update!(status: "initiated")
        else
          Transaction.create!(
            id: data[:transaction_id],
            merchant_id: data[:merchant_id],
            idempotency_key: data[:idempotency_key],
            amount_cents: data[:amount_cents],
            currency: data[:currency],
            card_last_four: data[:card_last_four],
            card_brand: data[:card_brand],
            status: "initiated",
            metadata: data[:metadata] || {}
          )
        end
      end

      def handle_authorized(event)
        update_transaction(event.data[:transaction_id],
          status: "authorized",
          authorization_code: event.data[:authorization_code],
          authorized_at: event.data[:authorized_at]
        )
      end

      def handle_auth_failed(event)
        update_transaction(event.data[:transaction_id],
          status: "failed",
          failure_reason: event.data[:reason],
          failed_at: Time.current
        )
      end

      def handle_fraud_passed(event)
        update_transaction(event.data[:transaction_id],
          status: "fraud_cleared",
          fraud_score: event.data[:score],
          fraud_decision: event.data[:decision],
          fraud_explanation: event.data[:explanation]
        )
      end

      def handle_fraud_failed(event)
        update_transaction(event.data[:transaction_id],
          status: "blocked",
          fraud_score: event.data[:score],
          fraud_decision: "block",
          fraud_explanation: event.data[:explanation]
        )
      end

      def handle_captured(event)
        update_transaction(event.data[:transaction_id],
          status: "captured",
          captured_at: event.data[:captured_at]
        )
      end

      def handle_settled(event)
        update_transaction(event.data[:transaction_id],
          status: "settled",
          settled_at: event.data[:settled_at]
        )
      end

      def handle_failed(event)
        update_transaction(event.data[:transaction_id],
          status: "failed",
          failed_at: Time.current
        )
      end

      def handle_refunded(event)
        update_transaction(event.data[:transaction_id],
          status: "refunded",
          refunded_at: event.data[:refunded_at]
        )
      end

      def handle_partially_refunded(event)
        update_transaction(event.data[:transaction_id],
          status: "partially_refunded"
        )
      end

      def handle_voided(event)
        update_transaction(event.data[:transaction_id],
          status: "voided"
        )
      end

      def update_transaction(transaction_id, **attrs)
        txn = Transaction.find_by(id: transaction_id)
        return unless txn

        txn.update!(**attrs)
      end
    end
  end
end
