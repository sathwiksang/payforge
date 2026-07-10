class FailedCompensation < ApplicationRecord
  belongs_to :transaction, class_name: "Transaction"

  STATUSES = %w[pending resolved].freeze

  validates :step, presence: true
  validates :compensation, presence: true
  validates :error, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :resolved, -> { where(status: "resolved") }
end
