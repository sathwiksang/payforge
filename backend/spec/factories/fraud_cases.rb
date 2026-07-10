FactoryBot.define do
  factory :fraud_case, class: "Fraud::Models::FraudCase" do
    association :payment_transaction, factory: :transaction
    association :merchant
    status { "open" }
    priority { :medium }
    risk_score { 0.75 }
    decision { "review" }
    model_used { "lightgbm_onnx_v1" }
    latency_ms { 0.45 }
    matched_rules { [] }
    shap_values { {} }
    feature_vector { [] }

    trait :blocked do
      decision { "block" }
      risk_score { 0.95 }
      priority { :critical }
    end

    trait :resolved do
      status { "false_positive" }
      reviewed_at { Time.current }
      resolved_at { Time.current }
      association :reviewer, factory: :user
    end
  end
end
