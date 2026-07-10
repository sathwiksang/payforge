Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_options = lambda do |event|
    {
      correlation_id: event.payload[:headers]&.fetch("X-Correlation-Id", nil),
      request_id: event.payload[:request_id],
      remote_ip: event.payload[:remote_ip],
      user_agent: event.payload[:user_agent]
    }.compact
  end
  config.lograge.custom_payload do |controller|
    {
      remote_ip: controller.request.remote_ip,
      user_agent: controller.request.user_agent
    }
  end
end
