module Fraud
  module Services
    module Rules
      class RoundAmountRule < BaseRule
        def initialize(name:, threshold_cents:, severity:)
          super(name: name, severity: severity, description: "Suspiciously round amount above $#{threshold_cents / 100}")
          @threshold_cents = threshold_cents
        end

        def matches?(transaction)
          transaction.amount_cents >= @threshold_cents &&
            (transaction.amount_cents % 10_000).zero?
        end
      end
    end
  end
end
