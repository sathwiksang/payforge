FactoryBot.define do
  factory :merchant do
    name { Faker::Company.name }
    email_ciphertext { Faker::Internet.email }
    status { "active" }
    fee_percentage { 2.9 }
    fee_fixed_cents { 30 }
    settings { {} }

    trait :with_webhook do
      webhook_url_ciphertext { "https://example.com/webhooks" }
      webhook_secret_ciphertext { SecureRandom.hex(32) }
    end
  end
end
