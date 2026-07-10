module Fraud
  module Services
    module Rules
      class TimeRule < BaseRule
        def initialize(name:, start_hour:, end_hour:, severity:)
          super(name: name, severity: severity, description: "Transaction during off-hours (#{start_hour}:00-#{end_hour}:00)")
          @start_hour = start_hour
          @end_hour = end_hour
        end

        def matches?(transaction)
          hour = transaction.created_at.hour
          hour >= @start_hour && hour < @end_hour
        end
      end
    end
  end
end
