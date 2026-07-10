#!/usr/bin/env ruby
# Script to benchmark API response times and fraud scoring latency
# Run: bin/rails runner script/benchmark_api.rb

require "benchmark"

puts "PayForge API Performance Benchmark"
puts "=" * 50

# Ensure seeded data exists
user = User.find_by(email: "admin@payforge.dev")
merchant = user&.merchant || Merchant.joins(:transactions).first
unless merchant
  puts "No seed data found. Run: bin/rails db:seed"
  exit 1
end

transactions = merchant.transactions.limit(100).to_a
if transactions.empty?
  # Fall back to any merchant with transactions
  merchant = Merchant.joins(:transactions).first
  transactions = merchant&.transactions&.limit(100)&.to_a || []
end

if transactions.empty?
  puts "No transactions found. Run: bin/rails db:seed"
  exit 1
end

# 1. Transaction list query
puts "\n1. Transaction List Query (merchant-scoped, ordered)"
results = Benchmark.measure do
  100.times do
    merchant.transactions.order(created_at: :desc).limit(25).includes(:merchant).to_a
  end
end
avg_ms = (results.real / 100 * 1000).round(2)
puts "   Avg: #{avg_ms}ms per query (100 iterations)"
puts "   #{avg_ms < 200 ? 'PASS' : 'NEEDS OPTIMIZATION'}: target < 200ms"

# 2. Transaction detail with ledger entries
puts "\n2. Transaction Detail + Ledger Entries"
txn = transactions.first
results = Benchmark.measure do
  100.times do
    Transaction.includes(:ledger_entries, :merchant).find(txn.id)
  end
end
avg_ms = (results.real / 100 * 1000).round(2)
puts "   Avg: #{avg_ms}ms per query (100 iterations)"
puts "   #{avg_ms < 200 ? 'PASS' : 'NEEDS OPTIMIZATION'}: target < 200ms"

# 3. Fraud case list with transaction
puts "\n3. Fraud Case List (with transaction eager load)"
results = Benchmark.measure do
  100.times do
    Fraud::Models::FraudCase.includes(:payment_transaction)
      .where(merchant_id: merchant.id)
      .order(created_at: :desc)
      .limit(25)
      .to_a
  end
end
avg_ms = (results.real / 100 * 1000).round(2)
puts "   Avg: #{avg_ms}ms per query (100 iterations)"
puts "   #{avg_ms < 200 ? 'PASS' : 'NEEDS OPTIMIZATION'}: target < 200ms"

# 4. Analytics aggregation
puts "\n4. Merchant Analytics Aggregation"
results = Benchmark.measure do
  50.times do
    captured = merchant.transactions.where(status: "captured")
    {
      total_volume: captured.sum(:amount_cents),
      total_revenue: captured.sum(:fee_cents),
      count: merchant.transactions.count,
      fraud_rate: merchant.transactions.where(fraud_decision: "block").count.to_f / [merchant.transactions.count, 1].max,
      avg_amount: captured.average(:amount_cents)
    }
  end
end
avg_ms = (results.real / 50 * 1000).round(2)
puts "   Avg: #{avg_ms}ms per aggregation (50 iterations)"
puts "   #{avg_ms < 200 ? 'PASS' : 'NEEDS OPTIMIZATION'}: target < 200ms"

# 5. Fraud scoring latency
puts "\n5. Fraud Scoring Engine Latency"
engine = Fraud::Services::FraudScoringEngine.new
test_txn = transactions.find { |t| t.status == "captured" } || transactions.first

results = Benchmark.measure do
  100.times do
    engine.score(test_txn)
  end
end
avg_ms = (results.real / 100 * 1000).round(2)
puts "   Avg: #{avg_ms}ms per scoring (100 iterations)"
puts "   #{avg_ms < 5 ? 'PASS' : 'NEEDS OPTIMIZATION'}: target < 5ms"

# 6. Double-entry ledger verification
puts "\n6. Ledger Balance Integrity Check"
ledger = Ledger::Services::DoubleEntryService.new
results = Benchmark.measure do
  10.times { ledger.verify_balance_integrity! }
end
avg_ms = (results.real / 10 * 1000).round(2)
puts "   Avg: #{avg_ms}ms per verification (10 iterations)"

puts "\n" + "=" * 50
puts "Benchmark complete."
