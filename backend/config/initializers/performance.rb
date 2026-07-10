# Performance configuration

# Redis cache store for development/production
# In development we use memory_store by default (set in environments/development.rb)
# In production, use Redis for distributed caching
if Rails.env.production?
  Rails.application.config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" },
    namespace: "payforge_cache",
    expires_in: 5.minutes,
    pool_size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i,
    error_handler: ->(method:, returning:, exception:) {
      Rails.logger.warn("Redis cache error: #{method} => #{exception.class}: #{exception.message}")
    }
  }
end
