class Capture
  def self.process(authorization, payload)
    capture_amount = payload["amount"] || authorization[:amount]

    if capture_amount > authorization[:amount]
      return {
        id: "cap_#{SecureRandom.hex(12)}",
        authorization_id: authorization[:id],
        status: "error",
        error: "capture_amount_exceeds_authorization",
        timestamp: Time.now.utc.iso8601
      }
    end

    {
      id: "cap_#{SecureRandom.hex(12)}",
      authorization_id: authorization[:id],
      status: "captured",
      amount: capture_amount,
      currency: authorization[:currency],
      partial: capture_amount < authorization[:amount],
      timestamp: Time.now.utc.iso8601
    }
  end
end
