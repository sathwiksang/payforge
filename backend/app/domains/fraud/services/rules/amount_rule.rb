module Fraud
  module Services
    module Rules
      class AmountRule < BaseRule
        def initialize(name:, threshold_cents:, severity:)
          super(name: name, severity: severity, description: "Amount exceeds $#{threshold_cents / 100}")
          @threshold_cents = threshold_cents
        end

        def matches?(transaction)
          transaction.amount_cents >= @threshold_cents
        end
      end
    end
  end
end
