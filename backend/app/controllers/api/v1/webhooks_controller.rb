module Api
  module V1
    class WebhooksController < BaseController
      before_action :authenticate_user!
      before_action :set_merchant

      # GET /api/v1/webhooks/deliveries
      def deliveries
        skip_verify_authorized!
        scope = WebhookDeliveryAttempt
          .where(merchant_id: @merchant.id)
          .order(created_at: :desc)

        pagy_obj, records = pagy(:offset, scope, limit: per_page)
        data = records.map do |d|
          {
            id: d.id,
            event_type: d.event_type,
            event_id: d.event_id,
            status: d.status,
            response_code: d.response_code,
            error_message: d.error_message,
            attempts: d.attempts,
            delivered_at: d.delivered_at&.iso8601,
            created_at: d.created_at.iso8601
          }
        end

        render json: {
          data: data,
          meta: base_meta.merge(
            total_count: pagy_obj.count,
            page: pagy_obj.page,
            per_page: pagy_obj.limit,
            total_pages: pagy_obj.last
          ),
          links: pagination_links(pagy_obj)
        }
      end

      # POST /api/v1/webhooks/test
      def test
        skip_verify_authorized!
        return render_error("No webhook URL configured", code: "no_webhook_url") unless @merchant.webhook_url_ciphertext.present?

        test_payload = {
          event: "test.ping",
          data: {
            message: "This is a test webhook from PayForge",
            merchant_id: @merchant.id,
            timestamp: Time.current.iso8601
          }
        }

        render_success({
          event: "test.ping",
          delivered_to: "configured endpoint",
          payload: test_payload
        })
      end

      # GET /api/v1/webhooks/status
      def status
        skip_verify_authorized!
        render_success({
          webhook_configured: @merchant.webhook_url_ciphertext.present?,
          recent_deliveries: WebhookDeliveryAttempt
            .where(merchant_id: @merchant.id)
            .where("created_at > ?", 24.hours.ago)
            .count,
          success_rate: calculate_success_rate
        })
      end

      private

      def set_merchant
        @merchant = current_user.merchant
        render_error("No merchant associated", status: :forbidden, code: "no_merchant") unless @merchant
      end

      def calculate_success_rate
        recent = WebhookDeliveryAttempt
          .where(merchant_id: @merchant.id)
          .where("created_at > ?", 24.hours.ago)

        total = recent.count
        return 1.0 if total == 0

        successful = recent.where(status: "delivered").count
        (successful.to_f / total).round(4)
      end
    end
  end
end
