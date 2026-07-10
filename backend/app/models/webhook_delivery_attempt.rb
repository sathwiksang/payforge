class WebhookDeliveryAttempt < ApplicationRecord
  belongs_to :merchant

  STATUSES = %w[pending delivered failed exhausted].freeze

  validates :event_type, presence: true
  validates :event_id, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :attempts, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  scope :pending, -> { where(status: "pending") }
  scope :failed, -> { where(status: "failed") }
  scope :exhausted, -> { where(status: "exhausted") }
end
