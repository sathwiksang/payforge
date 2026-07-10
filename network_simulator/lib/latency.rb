class Latency
  def self.simulate(operation, config)
    op_config = config.dig("defaults", "latency", operation.to_s)
    return unless op_config

    min_ms = op_config["min_ms"] || 50
    max_ms = op_config["max_ms"] || 200
    delay = rand(min_ms..max_ms) / 1000.0
    sleep(delay)
  end
end
