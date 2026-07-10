class ServiceAuthentication
  SERVICE_HEADER = "HTTP_X_SERVICE_KEY"

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    # Only check internal service paths
    if request.path.start_with?("/internal/")
      service_key = env[SERVICE_HEADER]
      expected_key = Rails.application.credentials.service_api_key ||
                     ENV.fetch("SERVICE_API_KEY", "dev_service_key")

      unless ActiveSupport::SecurityUtils.secure_compare(service_key.to_s, expected_key)
        return [
          401,
          { "Content-Type" => "application/json" },
          [{ error: "Invalid service key" }.to_json]
        ]
      end

      env["payforge.service_authenticated"] = true
    end

    @app.call(env)
  end
end
