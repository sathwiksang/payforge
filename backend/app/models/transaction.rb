class Transaction < ApplicationRecord
  include Auditable

  belongs_to :merchant
  has_many :ledger_entries, foreign_key: "transaction_id", dependent: :restrict_with_error

  STATUSES = %w[
    pending initiated authorized fraud_cleared captured
    settled failed refunded partially_refunded voided blocked
  ].freeze
  FRAUD_DECISIONS = %w[pass review block].freeze

  validates :idempotency_key, presence: true, uniqueness: { scope: :merchant_id }
  validates :status, presence: true, inclusion: { in: STATUSES }
  MINIMUM_AMOUNT_CENTS = 50 # Minimum transaction: $0.50 (covers any fee structure)

  validates :amount_cents, presence: true, numericality: { greater_than_or_equal_to: MINIMUM_AMOUNT_CENTS, only_integer: true }
  validates :currency, presence: true, length: { is: 3 }
  validates :fraud_decision, inclusion: { in: FRAUD_DECISIONS }, allow_nil: true
  validates :fee_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
  validates :net_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true

  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }

  monetize :amount_cents, as: :amount, with_model_currency: :currency
  monetize :fee_cents, as: :fee, with_model_currency: :currency, allow_nil: true
  monetize :net_cents, as: :net, with_model_currency: :currency, allow_nil: true

  before_validation :calculate_fee_and_net, if: -> { amount_cents.present? && fee_cents.nil? && merchant.present? }

  def authorized?
    status == "authorized"
  end

  def capturable?
    status.in?(%w[authorized fraud_cleared])
  end

  def refundable?
    status.in?(%w[captured settled])
  end

  private

  def calculate_fee_and_net
    self.fee_cents = merchant.calculate_fee(amount_cents)
    self.net_cents = amount_cents - fee_cents
  end
end
