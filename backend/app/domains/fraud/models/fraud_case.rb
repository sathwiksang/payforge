module Fraud
  module Models
    class FraudCase < ApplicationRecord
      include Auditable

      belongs_to :payment_transaction, class_name: "Transaction", foreign_key: "transaction_id"
      belongs_to :merchant
      belongs_to :reviewer, class_name: "User", optional: true

      STATUSES = %w[open under_review confirmed_fraud false_positive escalated].freeze
      PRIORITIES = %w[low medium high critical].freeze
      DECISIONS = %w[pass review block].freeze

      validates :status, presence: true, inclusion: { in: STATUSES }
      validates :priority, presence: true
      validates :decision, presence: true, inclusion: { in: DECISIONS }
      validates :model_used, presence: true
      validates :risk_score, presence: true,
                numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

      scope :pending_review, -> { where(status: %w[open under_review]).order(risk_score: :desc) }
      scope :by_priority, -> { order(priority: :desc, risk_score: :desc) }

      enum :priority, { low: 0, medium: 1, high: 2, critical: 3 }

      def resolve!(status:, reviewer:, notes: nil)
        update!(
          status: status,
          reviewer: reviewer,
          notes: notes,
          reviewed_at: Time.current,
          resolved_at: Time.current
        )
      end
    end
  end
end
