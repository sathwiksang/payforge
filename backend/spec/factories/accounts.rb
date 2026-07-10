FactoryBot.define do
  factory :account do
    scope { "processing" }
    account_type { "asset" }
    currency { "USD" }
    balance_cents { 0 }
    active { true }
    merchant { nil }
  end
end
