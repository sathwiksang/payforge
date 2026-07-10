module Fraud
  module Services
    module Rules
      class VelocityRule < BaseRule
        def initialize(name:, window:, max_count:, severity:)
          super(name: name, severity: severity, description: "More than #{max_count} transactions in #{window / 60}min")
          @window = window
          @max_count = max_count
        end

        def matches?(transaction)
          count = Transaction.where(card_last_four: transaction.card_last_four)
                             .where("created_at > ?", transaction.created_at - @window)
                             .where.not(id: transaction.id)
                             .count
          count >= @max_count
        end
      end
    end
  end
end
