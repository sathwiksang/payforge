FactoryBot.define do
  factory :fraud_rule, class: "Fraud::Models::FraudRule" do
    sequence(:name) { |n| "rule_#{n}" }
    rule_type { "amount" }
    severity { "medium" }
    description { "Test fraud rule" }
    conditions { { threshold_cents: 100_000 } }
    enabled { true }
    position { 0 }
  end
end
