module Webhooks
  module Services
    class WebhookDeliveryService
      MAX_RETRIES = 5
      RETRY_DELAYS = [1.minute, 5.minutes, 30.minutes, 2.hours, 24.hours].freeze

      def deliver_payment_captured(transaction)
        deliver_event(
          merchant: transaction.merchant,
          event_type: "payment.captured",
          data: {
            transaction_id: transaction.id,
            amount_cents: transaction.amount_cents,
            currency: transaction.currency,
            fee_cents: transaction.fee_cents,
            net_cents: transaction.net_cents,
            status: transaction.status,
            captured_at: transaction.captured_at&.iso8601
          }
        )
      end

      def deliver_payment_failed(transaction)
        deliver_event(
          merchant: transaction.merchant,
          event_type: "payment.failed",
          data: {
            transaction_id: transaction.id,
            amount_cents: transaction.amount_cents,
            currency: transaction.currency,
            status: transaction.status,
            failure_reason: transaction.failure_reason
          }
        )
      end

      def deliver_payment_refunded(transaction, refund_amount_cents:)
        deliver_event(
          merchant: transaction.merchant,
          event_type: "payment.refunded",
          data: {
            transaction_id: transaction.id,
            refund_amount_cents: refund_amount_cents,
            currency: transaction.currency,
            status: transaction.status
          }
        )
      end

      private

      def deliver_event(merchant:, event_type:, data:)
        return unless merchant.webhook_url_ciphertext.present?

        payload = build_payload(event_type, data)

        delivery = WebhookDeliveryAttempt.create!(
          merchant: merchant,
          event_type: event_type,
          event_id: payload[:id],
          payload: payload,
          status: "pending"
        )

        WebhookDeliveryJob.perform_async(delivery.id, 0)
      end

      def build_payload(event_type, data)
        {
          id: "evt_#{SecureRandom.hex(16)}",
          type: event_type,
          created_at: Time.current.iso8601,
          data: data
        }
      end
    end
  end
end
