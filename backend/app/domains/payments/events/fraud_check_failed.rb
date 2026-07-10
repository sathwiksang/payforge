module Payments
  module Events
    class FraudCheckFailed < RailsEventStore::Event; end
  end
end
