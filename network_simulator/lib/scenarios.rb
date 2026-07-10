class Scenarios
  def self.load_config
    config_path = File.join(File.dirname(__FILE__), "..", "config", "scenarios.yml")
    YAML.safe_load(File.read(config_path))
  end

  def self.card_scenario(card_number, config)
    return nil unless card_number
    last_four = card_number[-4..]
    test_cards = config["test_cards"] || {}
    test_cards[last_four]
  end

  def self.random_decline?(config)
    rate = config.dig("defaults", "decline_rate") || 0.05
    rand < rate
  end

  def self.random_avs(config)
    results = config["avs_results"] || ["Y"]
    results.sample
  end

  def self.random_cvv(config)
    results = config["cvv_results"] || ["M"]
    results.sample
  end
end
