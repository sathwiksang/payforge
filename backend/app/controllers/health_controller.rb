class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def show
    checks = {
      database: check_database,
      redis: check_redis,
      event_store: check_event_store
    }

    healthy = checks.values.all? { |c| c[:status] == "ok" }
    status_code = healthy ? :ok : :service_unavailable

    render json: {
      status: healthy ? "healthy" : "degraded",
      timestamp: Time.current.iso8601,
      checks: checks
    }, status: status_code
  end

  private

  def check_database
    latency = measure { ActiveRecord::Base.connection.execute("SELECT 1") }
    { status: "ok", latency_ms: latency }
  rescue => e
    { status: "error", message: e.message }
  end

  def check_redis
    latency = measure { Redis.new(url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/0" }).ping }
    { status: "ok", latency_ms: latency }
  rescue => e
    { status: "error", message: e.message }
  end

  def check_event_store
    store = Rails.configuration.event_store
    { status: store ? "ok" : "error" }
  rescue => e
    { status: "error", message: e.message }
  end

  def measure
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
  end
end
