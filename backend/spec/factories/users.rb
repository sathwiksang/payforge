FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "SecurePass12!!" }
    password_confirmation { "SecurePass12!!" }
    role { "viewer" }
    association :merchant

    trait :admin do
      role { "admin" }
    end

    trait :super_admin do
      role { "super_admin" }
    end

    trait :manager do
      role { "manager" }
    end

    trait :analyst do
      role { "analyst" }
    end
  end
end
