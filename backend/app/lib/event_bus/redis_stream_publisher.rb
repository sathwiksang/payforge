module EventBus
  class RedisStreamPublisher
    STREAM_NAME = "payforge:events"
    MAX_STREAM_LENGTH = 100_000

    def initialize(redis: Redis.new)
      @redis = redis
    end

    def publish(event)
      @redis.xadd(STREAM_NAME, {
        event_type: event.class.name,
        event_id: event.event_id,
        data: Oj.dump(event.data, mode: :compat),
        metadata: Oj.dump(event.metadata.to_h, mode: :compat),
        timestamp: Time.current.to_f.to_s
      }, maxlen: ["~", MAX_STREAM_LENGTH])
    rescue Redis::BaseError => e
      Rails.logger.error("Redis stream publish failed: #{e.message}")
      nil
    end

    def read(last_id: "0-0", count: 100)
      @redis.xrange(STREAM_NAME, last_id, "+", count: count)
    rescue Redis::BaseError => e
      Rails.logger.error("Redis stream read failed: #{e.message}")
      []
    end
  end
end
