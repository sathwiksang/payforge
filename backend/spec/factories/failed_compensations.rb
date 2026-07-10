FactoryBot.define do
  factory :failed_compensation do
    association :transaction
    step { "authorize_with_network" }
    compensation { "void_authorization" }
    error { "Connection refused" }
    status { "pending" }
  end
end
