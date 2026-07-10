module Fraud
  module Services
    module Rules
      class FirstTransactionRule < BaseRule
        def initialize(name:, threshold_cents:, severity:)
          super(name: name, severity: severity, description: "First transaction from card above $#{threshold_cents / 100}")
          @threshold_cents = threshold_cents
        end

        def matches?(transaction)
          return false if transaction.amount_cents < @threshold_cents

          !Transaction.where(card_last_four: transaction.card_last_four)
                      .where("created_at < ?", transaction.created_at)
                      .exists?
        end
      end
    end
  end
end
