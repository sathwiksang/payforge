module Fraud
  module Services
    class RuleEngine
      def initialize
        @rules = build_rules
      end

      def evaluate(transaction)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        matched = []

        @rules.each do |rule|
          if rule.matches?(transaction)
            matched << { name: rule.name, severity: rule.severity, description: rule.description }
          end
        end

        hard_block = matched.any? { |r| r[:severity] == "critical" }
        latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

        RuleResult.new(matched_rules: matched, hard_block: hard_block, latency_ms: latency_ms)
      end

      private

      def build_rules
        [
          Rules::VelocityRule.new(name: "rapid_fire_5min", window: 5.minutes, max_count: 5, severity: "critical"),
          Rules::VelocityRule.new(name: "rapid_fire_1hr", window: 1.hour, max_count: 20, severity: "high"),
          Rules::AmountRule.new(name: "very_high_amount", threshold_cents: 500_000, severity: "high"),
          Rules::AmountRule.new(name: "extreme_amount", threshold_cents: 1_000_000, severity: "critical"),
          Rules::RoundAmountRule.new(name: "suspicious_round_amount", threshold_cents: 100_000, severity: "medium"),
          Rules::TimeRule.new(name: "off_hours", start_hour: 2, end_hour: 5, severity: "low"),
          Rules::FirstTransactionRule.new(name: "first_tx_high_value", threshold_cents: 50_000, severity: "high"),
        ]
      end
    end

    RuleResult = Struct.new(:matched_rules, :hard_block, :latency_ms, keyword_init: true) do
      def hard_block?
        hard_block
      end
    end
  end
end
