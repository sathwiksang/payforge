FactoryBot.define do
  factory :transaction do
    merchant
    idempotency_key { "idem_#{SecureRandom.hex(16)}" }
    status { "pending" }
    amount_cents { 5000 }
    currency { "USD" }
    card_last_four { "4242" }
    card_brand { "visa" }
    metadata { {} }

    after(:build) do |txn|
      if txn.fee_cents.nil? && txn.merchant.present?
        txn.fee_cents = txn.merchant.calculate_fee(txn.amount_cents)
        txn.net_cents = txn.amount_cents - txn.fee_cents
      end
    end

    trait :authorized do
      status { "authorized" }
      authorized_at { Time.current }
      authorization_code { "A#{SecureRandom.hex(3).upcase}" }
    end

    trait :captured do
      authorized
      status { "captured" }
      captured_at { Time.current }
    end

    trait :settled do
      captured
      status { "settled" }
      settled_at { Time.current }
    end

    trait :large do
      amount_cents { 500_000 }
    end

    trait :small do
      amount_cents { 100 }
    end
  end
end
