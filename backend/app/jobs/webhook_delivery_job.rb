class WebhookDeliveryJob
  include Sidekiq::Job

  sidekiq_options queue: :webhooks, retry: false

  def perform(delivery_id, attempt = 0)
    delivery = WebhookDeliveryAttempt.find(delivery_id)
    merchant = delivery.merchant

    webhook_url = merchant.webhook_url_ciphertext
    webhook_secret = merchant.webhook_secret_ciphertext

    return delivery.update!(status: "failed", error_message: "No webhook URL configured") unless webhook_url.present?

    response = deliver(webhook_url, delivery.payload, webhook_secret || "")

    if response.success?
      delivery.update!(
        status: "delivered",
        response_code: response.status,
        delivered_at: Time.current,
        attempts: attempt + 1
      )
    else
      handle_failure(delivery, attempt, response)
    end
  rescue Faraday::Error => e
    handle_failure(delivery, attempt, nil, e.message)
  end

  private

  def deliver(url, payload, secret)
    timestamp = Time.current.to_i
    body = Oj.dump(payload, mode: :compat)
    signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")

    Faraday.post(url) do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["X-PayForge-Signature"] = "t=#{timestamp},v1=#{signature}"
      req.headers["X-PayForge-Event-Id"] = payload[:id] || payload["id"]
      req.body = body
      req.options.timeout = 10
    end
  end

  def handle_failure(delivery, attempt, response, error = nil)
    delivery.update!(
      status: "failed",
      response_code: response&.status,
      error_message: (error || response&.body.to_s).truncate(500),
      attempts: attempt + 1
    )

    max_retries = Webhooks::Services::WebhookDeliveryService::MAX_RETRIES
    delays = Webhooks::Services::WebhookDeliveryService::RETRY_DELAYS

    if attempt < max_retries
      delay = delays[attempt] || delays.last
      WebhookDeliveryJob.perform_in(delay, delivery.id, attempt + 1)
    else
      delivery.update!(status: "exhausted")
    end
  end
end
