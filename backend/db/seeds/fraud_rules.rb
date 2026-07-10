Fraud::Models::FraudRule.find_or_create_by!(name: "rapid_fire_5min") do |r|
  r.rule_type = "velocity"
  r.severity = "critical"
  r.description = "More than 5 transactions in 5 minutes from same card"
  r.conditions = { window_minutes: 5, max_count: 5 }
  r.position = 1
end

Fraud::Models::FraudRule.find_or_create_by!(name: "rapid_fire_1hr") do |r|
  r.rule_type = "velocity"
  r.severity = "high"
  r.description = "More than 20 transactions in 1 hour from same card"
  r.conditions = { window_minutes: 60, max_count: 20 }
  r.position = 2
end

Fraud::Models::FraudRule.find_or_create_by!(name: "very_high_amount") do |r|
  r.rule_type = "amount"
  r.severity = "high"
  r.description = "Transaction amount exceeds $5,000"
  r.conditions = { threshold_cents: 500_000 }
  r.position = 3
end

Fraud::Models::FraudRule.find_or_create_by!(name: "extreme_amount") do |r|
  r.rule_type = "amount"
  r.severity = "critical"
  r.description = "Transaction amount exceeds $10,000"
  r.conditions = { threshold_cents: 1_000_000 }
  r.position = 4
end

Fraud::Models::FraudRule.find_or_create_by!(name: "suspicious_round_amount") do |r|
  r.rule_type = "round_amount"
  r.severity = "medium"
  r.description = "Suspiciously round amount above $1,000"
  r.conditions = { threshold_cents: 100_000 }
  r.position = 5
end

Fraud::Models::FraudRule.find_or_create_by!(name: "off_hours") do |r|
  r.rule_type = "time"
  r.severity = "low"
  r.description = "Transaction during off-hours (2:00-5:00 AM)"
  r.conditions = { start_hour: 2, end_hour: 5 }
  r.position = 6
end

Fraud::Models::FraudRule.find_or_create_by!(name: "first_tx_high_value") do |r|
  r.rule_type = "first_transaction"
  r.severity = "high"
  r.description = "First transaction from card above $500"
  r.conditions = { threshold_cents: 50_000 }
  r.position = 7
end

puts "Seeded #{Fraud::Models::FraudRule.count} fraud rules"
