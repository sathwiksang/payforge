FactoryBot.define do
  factory :webhook_delivery_attempt do
    merchant
    event_type { "payment.captured" }
    event_id { "evt_#{SecureRandom.hex(16)}" }
    payload { { id: event_id, type: event_type, data: { amount: 5000 } } }
    status { "pending" }
    attempts { 0 }
  end
end
