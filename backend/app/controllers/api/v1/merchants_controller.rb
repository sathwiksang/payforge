module Api
  module V1
    class MerchantsController < BaseController
      before_action :authenticate_user!
      before_action :set_merchant

      # GET /api/v1/merchants/me
      def me
        authorize! @merchant, with: MerchantPolicy, to: :show?
        render_success(MerchantBlueprint.render_as_hash(@merchant, view: :profile))
      end

      # PATCH /api/v1/merchants/me
      def update_me
        authorize! @merchant, with: MerchantPolicy, to: :update?

        if @merchant.update(merchant_params)
          render_success(MerchantBlueprint.render_as_hash(@merchant.reload, view: :profile))
        else
          render_error(
            @merchant.errors.full_messages.join(", "),
            code: "validation_error"
          )
        end
      end

      # GET /api/v1/merchants/me/analytics
      def analytics
        authorize! @merchant, with: MerchantPolicy, to: :show?
        data = Rails.cache.fetch("merchant:#{@merchant.id}:analytics", expires_in: 1.minute) do
          MerchantBlueprint.render_as_hash(@merchant, view: :analytics)
        end
        render_success(data)
      end

      # GET /api/v1/merchants/me/analytics/volume
      def analytics_volume
        authorize! @merchant, with: MerchantPolicy, to: :show?
        range = params[:range] || "30d"
        days = case range
               when "7d" then 7
               when "30d" then 30
               when "90d" then 90
               when "1y" then 365
               else 30
               end

        data = Rails.cache.fetch("merchant:#{@merchant.id}:volume:#{range}", expires_in: 2.minutes) do
          start_date = days.days.ago.beginning_of_day
          daily = @merchant.transactions
                    .where("created_at >= ?", start_date)
                    .group("DATE(created_at)")
                    .select(
                      "DATE(created_at) AS date",
                      "SUM(amount_cents) AS volume_cents",
                      "COUNT(*) AS transaction_count"
                    )
                    .order("date ASC")

          daily.map do |row|
            {
              date: row.date.to_s,
              volume_cents: row.volume_cents.to_i,
              transaction_count: row.transaction_count.to_i
            }
          end
        end
        render_success(data)
      end

      # GET /api/v1/merchants/me/analytics/fraud_distribution
      def analytics_fraud_distribution
        authorize! @merchant, with: MerchantPolicy, to: :show?
        data = Rails.cache.fetch("merchant:#{@merchant.id}:fraud_dist", expires_in: 2.minutes) do
          ranges = [
            { range: "0.0-0.1", min: 0.0, max: 0.1 },
            { range: "0.1-0.2", min: 0.1, max: 0.2 },
            { range: "0.2-0.3", min: 0.2, max: 0.3 },
            { range: "0.3-0.4", min: 0.3, max: 0.4 },
            { range: "0.4-0.5", min: 0.4, max: 0.5 },
            { range: "0.5-0.6", min: 0.5, max: 0.6 },
            { range: "0.6-0.7", min: 0.6, max: 0.7 },
            { range: "0.7-0.8", min: 0.7, max: 0.8 },
            { range: "0.8-0.9", min: 0.8, max: 0.9 },
            { range: "0.9-1.0", min: 0.9, max: 1.0 }
          ]
          txns = @merchant.transactions.where.not(fraud_score: nil)
          ranges.map do |r|
            count = txns.where("fraud_score >= ? AND fraud_score < ?", r[:min], r[:max] == 1.0 ? 1.01 : r[:max]).count
            { range: r[:range], count: count }
          end
        end
        render_success(data)
      end

      # GET /api/v1/merchants/me/analytics/payment_methods
      def analytics_payment_methods
        authorize! @merchant, with: MerchantPolicy, to: :show?
        data = Rails.cache.fetch("merchant:#{@merchant.id}:payment_methods", expires_in: 2.minutes) do
          total = @merchant.transactions.count.to_f
          return [] if total.zero?

          @merchant.transactions
            .group(:card_brand)
            .count
            .map { |brand, count| { name: (brand || "Other").titleize, value: (count / total * 100).round(1) } }
            .sort_by { |h| -h[:value] }
        end
        render_success(data)
      end

      # GET /api/v1/merchants/me/analytics/recent_activity
      def analytics_recent_activity
        authorize! @merchant, with: MerchantPolicy, to: :show?
        data = Rails.cache.fetch("merchant:#{@merchant.id}:recent_activity", expires_in: 30.seconds) do
          activities = []

          # Recent transactions
          @merchant.transactions.order(created_at: :desc).limit(10).each do |tx|
            activity = case tx.status
                       when "captured"
                         { type: "payment_captured", title: "Payment captured", description: tx.amount.format }
                       when "refunded", "partially_refunded"
                         { type: "refund", title: "Refund processed", description: tx.amount.format }
                       when "blocked"
                         { type: "fraud_blocked", title: "Transaction blocked", description: "Fraud score: #{tx.fraud_score}" }
                       when "failed"
                         { type: "payment_failed", title: "Payment failed", description: tx.amount.format }
                       when "settled"
                         { type: "settlement", title: "Payment settled", description: tx.amount.format }
                       else
                         { type: "transaction", title: "Transaction #{tx.status}", description: tx.amount.format }
                       end
            activities << activity.merge(created_at: tx.created_at.iso8601)
          end

          # Recent fraud cases
          ::Fraud::FraudCase.where(merchant_id: @merchant.id).order(created_at: :desc).limit(5).each do |fc|
            activities << {
              type: "fraud_case",
              title: "Fraud case opened",
              description: "Risk score: #{(fc.risk_score.to_f * 100).round(1)}%",
              created_at: fc.created_at.iso8601
            }
          end

          activities.sort_by { |a| a[:created_at] }.reverse.first(10)
        end
        render_success(data)
      end

      # GET /api/v1/merchants/me/balance
      def balance
        authorize! @merchant, with: MerchantPolicy, to: :show?

        balances = Rails.cache.fetch("merchant:#{@merchant.id}:balance", expires_in: 30.seconds) do
          @merchant.accounts.map do |account|
            {
              id: account.id,
              account_type: account.account_type,
              currency: account.currency,
              balance_cents: account.balance_cents
            }
          end
        end

        render_success(balances)
      end

      # Admin-only endpoints

      # GET /api/v1/merchants
      def index
        authorize! Merchant, with: MerchantPolicy
        render_paginated(Merchant.order(created_at: :desc), MerchantBlueprint)
      end

      # GET /api/v1/merchants/:id
      def show
        merchant = Merchant.find(params[:id])
        authorize! merchant, with: MerchantPolicy
        render_success(MerchantBlueprint.render_as_hash(merchant, view: :profile))
      end

      # POST /api/v1/merchants
      def create
        authorize! Merchant, with: MerchantPolicy
        merchant = Merchant.new(admin_merchant_params)
        if merchant.save
          render_created(MerchantBlueprint.render_as_hash(merchant, view: :profile))
        else
          render_error(merchant.errors.full_messages.join(", "), code: "validation_error")
        end
      end

      private

      def set_merchant
        @merchant = current_user.merchant
        render_error("No merchant associated", status: :forbidden, code: "no_merchant") unless @merchant
      end

      def merchant_params
        params.permit(:name, :webhook_url)
      end

      def admin_merchant_params
        permitted = params.permit(:name, :email, :status, :fee_percentage, :fee_fixed_cents, :risk_tier)
        permitted[:email_ciphertext] = permitted.delete(:email) if permitted.key?(:email)
        permitted
      end
    end
  end
end
