module Api
  module V1
    class FraudCasesController < BaseController
      before_action :authenticate_user!
      before_action :set_merchant
      before_action :set_fraud_case, only: [:show, :review]

      # GET /api/v1/fraud/cases
      def index
        authorize! Fraud::Models::FraudCase, with: FraudCasePolicy
        scope = authorized_scope(
          Fraud::Models::FraudCase.all,
          type: :active_record_relation,
          with: FraudCasePolicy
        )
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(priority: params[:priority]) if params[:priority].present?
        scope = scope.includes(:payment_transaction).order(created_at: :desc)

        render_paginated(scope, FraudCaseBlueprint)
      end

      # GET /api/v1/fraud/cases/:id
      def show
        authorize! @fraud_case, with: FraudCasePolicy
        render_success(FraudCaseBlueprint.render_as_hash(@fraud_case, view: :detailed))
      end

      # POST /api/v1/fraud/cases/:id/review
      def review
        authorize! @fraud_case, to: :resolve?, with: FraudCasePolicy

        @fraud_case.resolve!(
          status: review_params[:status],
          reviewer: current_user,
          notes: review_params[:notes]
        )

        render_success(FraudCaseBlueprint.render_as_hash(@fraud_case.reload, view: :detailed))
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.message, code: "invalid_review")
      end

      # GET /api/v1/fraud/stats
      def stats
        authorize! Fraud::Models::FraudCase, to: :index?, with: FraudCasePolicy

        data = Rails.cache.fetch("merchant:#{@merchant.id}:fraud_stats", expires_in: 1.minute) do
          cases = Fraud::Models::FraudCase.where(merchant_id: @merchant.id)
          total_txns = @merchant.transactions.count

          {
            total_cases: cases.count,
            open_cases: cases.where(status: "open").count,
            fraud_rate: total_txns > 0 ? cases.where(decision: "block").count.to_f / total_txns : 0,
            avg_risk_score: cases.average(:risk_score)&.round(4) || 0,
            by_priority: {
              critical: cases.where(priority: "critical").count,
              high: cases.where(priority: "high").count,
              medium: cases.where(priority: "medium").count,
              low: cases.where(priority: "low").count
            }
          }
        end

        render_success(data)
      end

      private

      def set_merchant
        @merchant = current_user.merchant
        render_error("No merchant associated", status: :forbidden, code: "no_merchant") unless @merchant
      end

      def set_fraud_case
        @fraud_case = Fraud::Models::FraudCase.find(params[:id])
      end

      def review_params
        params.permit(:status, :notes)
      end
    end
  end
end
