module Fraud
  module Models
    class FraudRule < ApplicationRecord
      RULE_TYPES = %w[velocity amount round_amount time first_transaction].freeze
      SEVERITIES = %w[low medium high critical].freeze

      validates :name, presence: true, uniqueness: true
      validates :rule_type, presence: true, inclusion: { in: RULE_TYPES }
      validates :severity, presence: true, inclusion: { in: SEVERITIES }

      scope :active, -> { where(enabled: true).order(position: :asc) }
    end
  end
end
