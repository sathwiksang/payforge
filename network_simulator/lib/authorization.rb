class Authorization
  def self.process(payload, config)
    card_number = payload["card_number"]
    scenario = Scenarios.card_scenario(card_number, config)

    if scenario
      return handle_scenario(scenario, payload)
    end

    if Scenarios.random_decline?(config)
      return decline_response(payload, "05", "do_not_honor")
    end

    approve_response(payload, config)
  end

  def self.handle_scenario(scenario, payload)
    case scenario["response"]
    when "timeout"
      sleep((scenario["timeout_ms"] || 5000) / 1000.0)
      {
        id: "auth_#{SecureRandom.hex(12)}",
        status: "error",
        error: "network_timeout",
        amount: payload["amount"],
        currency: payload["currency"],
        timestamp: Time.now.utc.iso8601
      }
    when "approved"
      {
        id: "auth_#{SecureRandom.hex(12)}",
        status: "approved",
        authorization_code: "A#{SecureRandom.hex(3).upcase}",
        response_code: scenario["response_code"],
        avs_result: "Y",
        cvv_result: "M",
        network: detect_network(payload["card_number"]),
        amount: payload["amount"],
        currency: payload["currency"],
        processor_response_time_ms: rand(30..120),
        timestamp: Time.now.utc.iso8601
      }
    else
      decline_response(payload, scenario["response_code"], scenario["response"])
    end
  end

  def self.approve_response(payload, config)
    {
      id: "auth_#{SecureRandom.hex(12)}",
      status: "approved",
      authorization_code: "A#{SecureRandom.hex(3).upcase}",
      response_code: "00",
      avs_result: Scenarios.random_avs(config),
      cvv_result: Scenarios.random_cvv(config),
      network: detect_network(payload["card_number"]),
      amount: payload["amount"],
      currency: payload["currency"],
      processor_response_time_ms: rand(30..120),
      timestamp: Time.now.utc.iso8601
    }
  end

  def self.decline_response(payload, response_code, reason)
    {
      id: "auth_#{SecureRandom.hex(12)}",
      status: "declined",
      response_code: response_code,
      decline_reason: reason,
      network: detect_network(payload["card_number"]),
      amount: payload["amount"],
      currency: payload["currency"],
      processor_response_time_ms: rand(30..120),
      timestamp: Time.now.utc.iso8601
    }
  end

  def self.detect_network(card_number)
    return "unknown" unless card_number
    case card_number[0]
    when "4" then "visa"
    when "5" then "mastercard"
    when "3" then "amex"
    when "6" then "discover"
    else "unknown"
    end
  end
end
