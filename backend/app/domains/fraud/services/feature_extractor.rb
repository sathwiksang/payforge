module Fraud
  module Services
    class FeatureExtractor
      FEATURE_NAMES = %w[
        amount_cents log_amount hour_of_day day_of_week
        is_weekend is_business_hours card_brand currency
        tx_count_5min tx_count_1hr tx_count_24hr
        sum_amount_1hr sum_amount_24hr distinct_merchants_24hr
        merchant_avg_tx merchant_tx_count_30d merchant_chargeback_rate
        merchant_days_active merchant_risk_tier
        amount_deviation time_since_last_tx is_first_tx distance
      ].freeze

      def extract(transaction)
        merchant = transaction.merchant

        tx_features = [
          transaction.amount_cents.to_f,
          log_amount(transaction.amount_cents),
          hour_of_day(transaction.created_at),
          day_of_week(transaction.created_at),
          is_weekend?(transaction.created_at) ? 1.0 : 0.0,
          is_business_hours?(transaction.created_at) ? 1.0 : 0.0,
          card_brand_encoding(transaction.card_brand),
          currency_encoding(transaction.currency)
        ]

        velocity_features = [
          count_transactions_last_n_minutes(transaction, 5),
          count_transactions_last_n_minutes(transaction, 60),
          count_transactions_last_n_hours(transaction, 24),
          sum_amount_last_n_hours(transaction, 1),
          sum_amount_last_n_hours(transaction, 24),
          distinct_merchants_last_n_hours(transaction, 24)
        ]

        merchant_features = [
          merchant.average_transaction_cents.to_f,
          merchant.transaction_count_30d.to_f,
          merchant.chargeback_rate_90d.to_f,
          merchant.days_since_onboarding.to_f,
          merchant.risk_tier_encoding.to_f
        ]

        behavioral_features = [
          amount_deviation_from_merchant_avg(transaction),
          time_since_last_transaction(transaction),
          is_first_transaction_from_card?(transaction) ? 1.0 : 0.0,
          distance_from_merchant_location(transaction)
        ]

        (tx_features + velocity_features + merchant_features + behavioral_features)
          .map { |v| v.nil? ? 0.0 : v.to_f }
      end

      private

      def log_amount(cents)
        Math.log(1 + cents.to_f)
      end

      def hour_of_day(time)
        time.hour.to_f
      end

      def day_of_week(time)
        time.wday.to_f
      end

      def is_weekend?(time)
        time.saturday? || time.sunday?
      end

      def is_business_hours?(time)
        time.hour.between?(9, 17) && !is_weekend?(time)
      end

      def count_transactions_last_n_minutes(tx, minutes)
        Transaction.where(card_last_four: tx.card_last_four)
                   .where("created_at > ?", tx.created_at - minutes.minutes)
                   .where.not(id: tx.id)
                   .count.to_f
      end

      def count_transactions_last_n_hours(tx, hours)
        Transaction.where(card_last_four: tx.card_last_four)
                   .where("created_at > ?", tx.created_at - hours.hours)
                   .where.not(id: tx.id)
                   .count.to_f
      end

      def sum_amount_last_n_hours(tx, hours)
        Transaction.where(card_last_four: tx.card_last_four)
                   .where("created_at > ?", tx.created_at - hours.hours)
                   .sum(:amount_cents).to_f
      end

      def distinct_merchants_last_n_hours(tx, hours)
        Transaction.where(card_last_four: tx.card_last_four)
                   .where("created_at > ?", tx.created_at - hours.hours)
                   .distinct.count(:merchant_id).to_f
      end

      def amount_deviation_from_merchant_avg(tx)
        avg = tx.merchant.average_transaction_cents
        return 0.0 if avg.nil? || avg.zero?
        ((tx.amount_cents - avg).to_f / avg).abs
      end

      def time_since_last_transaction(tx)
        last_tx = Transaction.where(card_last_four: tx.card_last_four)
                             .where("created_at < ?", tx.created_at)
                             .order(created_at: :desc).first
        return 999_999.0 unless last_tx
        (tx.created_at - last_tx.created_at).to_f
      end

      def is_first_transaction_from_card?(tx)
        !Transaction.where(card_last_four: tx.card_last_four)
                    .where("created_at < ?", tx.created_at)
                    .exists?
      end

      def distance_from_merchant_location(tx)
        0.0 # Would use IP geolocation in production
      end

      def card_brand_encoding(brand)
        { "visa" => 0.0, "mastercard" => 1.0, "amex" => 2.0, "discover" => 3.0 }
          .fetch(brand&.downcase, 4.0)
      end

      def currency_encoding(currency)
        { "USD" => 0.0, "EUR" => 1.0, "GBP" => 2.0 }.fetch(currency, 3.0)
      end
    end
  end
end
