# PayForge Seed Data
# Generates a realistic demo dataset with 3 merchants, 5000+ transactions,
# fraud cases, and webhook delivery history.
#
# Run: bin/rails db:seed

require "securerandom"

puts "Seeding PayForge..."

# -- Merchants --

MERCHANTS = [
  {
    name: "CoffeeChain Co",
    email: "payments@coffeechain.co",
    fee_percentage: 2.9,
    fee_fixed_cents: 30,
    average_transaction_cents: 750,
    transaction_count_30d: 4200,
    chargeback_rate_90d: 0.005,
    risk_tier: "standard",
    profile: { avg: 750, volume: :high, fraud_rate: 0.01 }
  },
  {
    name: "TechGadgets Pro",
    email: "billing@techgadgets.pro",
    fee_percentage: 2.5,
    fee_fixed_cents: 25,
    average_transaction_cents: 15_000,
    transaction_count_30d: 800,
    chargeback_rate_90d: 0.02,
    risk_tier: "elevated",
    profile: { avg: 15_000, volume: :medium, fraud_rate: 0.03 }
  },
  {
    name: "BookWorm Digital",
    email: "finance@bookworm.digital",
    fee_percentage: 3.2,
    fee_fixed_cents: 35,
    average_transaction_cents: 1299,
    transaction_count_30d: 300,
    chargeback_rate_90d: 0.001,
    risk_tier: "standard",
    profile: { avg: 1299, volume: :low, fraud_rate: 0.005 }
  }
]

merchants = MERCHANTS.map do |attrs|
  profile = attrs.delete(:profile)
  merchant = Merchant.find_or_initialize_by(name: attrs[:name])
  merchant.assign_attributes(
    email_ciphertext: attrs.delete(:email),
    status: "active",
    onboarded_at: rand(90..365).days.ago,
    webhook_url_ciphertext: "https://#{attrs[:name].parameterize}.example.com/webhooks",
    webhook_secret_ciphertext: SecureRandom.hex(32),
    **attrs.except(:email)
  )
  merchant.save!
  puts "  Created merchant: #{merchant.name} (#{merchant.id})"
  { merchant: merchant, profile: profile }
end

# -- Users (one admin per merchant + demo admin) --

merchants.each do |m|
  merchant = m[:merchant]
  email = "admin@#{merchant.name.parameterize}.com"
  user = User.find_or_initialize_by(email: email)
  user.assign_attributes(
    password: "PayForge2026Secure",
    password_confirmation: "PayForge2026Secure",
    role: "admin",
    merchant: merchant
  )
  user.save!
  puts "  Created user: #{email} (admin)"
end

# Demo super admin
demo = User.find_or_initialize_by(email: "admin@payforge.dev")
demo.assign_attributes(
  password: "PayForge2026Secure",
  password_confirmation: "PayForge2026Secure",
  role: "super_admin",
  merchant: merchants.first[:merchant]
)
demo.save!
puts "  Created demo user: admin@payforge.dev (super_admin)"

# -- Transactions --

CARD_LAST_FOURS = %w[4242 5555 1234 8888 3333 7777 9999 6666 2222 4444].freeze
CARD_BRANDS = %w[visa mastercard amex discover].freeze
STATUSES_DIST = { "captured" => 85, "refunded" => 5, "failed" => 3, "blocked" => 2, "authorized" => 3, "voided" => 2 }.freeze

def pick_status
  roll = rand(100)
  cumulative = 0
  STATUSES_DIST.each do |status, pct|
    cumulative += pct
    return status if roll < cumulative
  end
  "captured"
end

def business_hour_offset(day_offset)
  # Peak hours: 10am-2pm, lower on weekends
  date = day_offset.days.ago.to_date
  is_weekend = date.saturday? || date.sunday?

  if is_weekend
    hour = rand(8..22)
  else
    # Bias toward business hours
    hour = if rand < 0.6
             rand(10..14) # peak
           elsif rand < 0.8
             rand(8..10)  # morning
           else
             rand(14..22) # afternoon/evening
           end
  end

  minute = rand(0..59)
  second = rand(0..59)
  Time.zone.local(date.year, date.month, date.day, hour, minute, second)
end

ledger_service = Ledger::Services::DoubleEntryService.new
total_tx = 0

merchants.each do |m|
  merchant = m[:merchant]
  profile = m[:profile]

  tx_count = case profile[:volume]
             when :high   then 2500
             when :medium then 1500
             when :low    then 500
             end

  puts "  Generating #{tx_count} transactions for #{merchant.name}..."

  tx_count.times do |i|
    # Amount distribution: log-normal around the merchant's average
    base = profile[:avg]
    multiplier = Math.exp(rand * 1.5 - 0.75) # ~0.47x to ~2.1x
    amount = (base * multiplier).round.clamp(Transaction::MINIMUM_AMOUNT_CENTS, 999_999)

    status = pick_status
    day_offset = rand(0..89)
    created_at = business_hour_offset(day_offset)

    card = CARD_LAST_FOURS.sample
    brand = CARD_BRANDS.sample

    # Determine fraud characteristics
    is_fraud = rand < profile[:fraud_rate]
    fraud_score = is_fraud ? rand(0.7..1.0).round(4) : rand(0.0..0.3).round(4)
    fraud_decision = if is_fraud && fraud_score >= 0.85
                       status = "blocked"
                       "block"
                     elsif is_fraud && fraud_score >= 0.60
                       "review"
                     else
                       "pass"
                     end

    txn = Transaction.new(
      merchant: merchant,
      idempotency_key: "seed_#{merchant.id}_#{i}",
      status: status,
      amount_cents: amount,
      currency: "USD",
      card_last_four: card,
      card_brand: brand,
      fraud_score: fraud_score,
      fraud_decision: fraud_decision,
      metadata: {},
      created_at: created_at,
      updated_at: created_at
    )

    # Calculate fees
    txn.fee_cents = merchant.calculate_fee(amount)
    txn.net_cents = amount - txn.fee_cents

    # Set timestamps based on status
    case status
    when "authorized"
      txn.authorized_at = created_at + rand(1..5).seconds
      txn.authorization_code = "A#{SecureRandom.hex(3).upcase}"
    when "captured"
      txn.authorized_at = created_at + rand(1..5).seconds
      txn.authorization_code = "A#{SecureRandom.hex(3).upcase}"
      txn.captured_at = created_at + rand(1..30).minutes
    when "settled"
      txn.authorized_at = created_at + rand(1..5).seconds
      txn.authorization_code = "A#{SecureRandom.hex(3).upcase}"
      txn.captured_at = created_at + rand(1..30).minutes
      txn.settled_at = created_at + rand(1..3).days
    when "refunded"
      txn.authorized_at = created_at + rand(1..5).seconds
      txn.authorization_code = "A#{SecureRandom.hex(3).upcase}"
      txn.captured_at = created_at + rand(1..30).minutes
      txn.refunded_at = created_at + rand(1..14).days
    when "failed"
      txn.failed_at = created_at + rand(1..5).seconds
      txn.failure_reason = %w[insufficient_funds card_declined expired_card processing_error].sample
    when "blocked"
      txn.authorized_at = created_at + rand(1..5).seconds
      txn.authorization_code = "A#{SecureRandom.hex(3).upcase}"
    when "voided"
      txn.authorized_at = created_at + rand(1..5).seconds
      txn.authorization_code = "A#{SecureRandom.hex(3).upcase}"
    end

    txn.save!(validate: false) # Skip validations for seed speed
    total_tx += 1

    # Create ledger entries for captured transactions
    if status == "captured" && i < 200 # Limit ledger entries for speed
      begin
        ledger_service.record_authorization(transaction: txn)
        ledger_service.record_capture(transaction: txn)
      rescue => e
        # Skip ledger errors for seed data
      end
    end

    print "\r    #{i + 1}/#{tx_count}" if (i + 1) % 100 == 0
  end
  puts ""
end

puts "  Created #{total_tx} transactions total"

# -- Fraud Cases --

fraud_txns = Transaction.where(fraud_decision: %w[block review]).order("RANDOM()").limit(50)
fraud_count = 0

fraud_txns.each do |txn|
  next if Fraud::Models::FraudCase.exists?(payment_transaction: txn)

  priority = case txn.fraud_score
             when 0.95..1.0 then "critical"
             when 0.85..0.95 then "high"
             when 0.70..0.85 then "medium"
             else "low"
             end

  # Mix of statuses: 40% open, 30% false_positive, 20% confirmed_fraud, 10% resolved
  case_status = case rand(10)
                when 0..3 then "open"
                when 4..6 then "false_positive"
                when 7..8 then "confirmed_fraud"
                else "open"
                end

  Fraud::Models::FraudCase.create!(
    payment_transaction: txn,
    merchant: txn.merchant,
    status: case_status,
    priority: priority,
    risk_score: txn.fraud_score,
    decision: txn.fraud_decision,
    model_used: "lightgbm_native_v1",
    latency_ms: rand(0.5..5.0).round(2),
    matched_rules: [
      { name: "amount_check", severity: priority == "critical" ? "critical" : "high" }
    ],
    shap_values: {
      "transaction_amount" => rand(0.05..0.3).round(4),
      "velocity_1h" => rand(-0.1..0.2).round(4),
      "merchant_history" => rand(-0.15..0.05).round(4)
    },
    feature_vector: Array.new(10) { rand(-2.0..2.0).round(4) },
    created_at: txn.created_at + rand(1..10).seconds
  )
  fraud_count += 1
end

puts "  Created #{fraud_count} fraud cases"

# -- Webhook Delivery Attempts --

webhook_count = 0
Transaction.where(status: %w[captured refunded]).order("RANDOM()").limit(200).each do |txn|
  next unless txn.merchant.webhook_url_ciphertext.present?

  # 95% success, 5% failure
  delivered = rand < 0.95
  WebhookDeliveryAttempt.create!(
    merchant: txn.merchant,
    event_type: "payment.#{txn.status}",
    event_id: "evt_#{SecureRandom.hex(16)}",
    payload: {
      id: "evt_#{SecureRandom.hex(16)}",
      type: "payment.#{txn.status}",
      data: { transaction_id: txn.id, amount_cents: txn.amount_cents }
    },
    status: delivered ? "delivered" : "failed",
    response_code: delivered ? 200 : [500, 502, 503, 0].sample,
    error_message: delivered ? nil : "Connection refused",
    attempts: delivered ? 1 : rand(1..5),
    delivered_at: delivered ? txn.created_at + rand(1..30).seconds : nil,
    created_at: txn.created_at
  )
  webhook_count += 1
end

puts "  Created #{webhook_count} webhook delivery attempts"

# -- Verify --

puts ""
puts "Seed complete!"
puts "  Merchants:     #{Merchant.count}"
puts "  Users:         #{User.count}"
puts "  Transactions:  #{Transaction.count}"
puts "  Fraud Cases:   #{Fraud::Models::FraudCase.count}"
puts "  Ledger Entries: #{LedgerEntry.count}"
puts "  Webhooks:      #{WebhookDeliveryAttempt.count}"
puts ""
puts "Login: admin@payforge.dev / PayForge2026Secure"
