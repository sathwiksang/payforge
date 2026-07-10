class LedgerEntry < ApplicationRecord
  belongs_to :account
  belongs_to :payment_transaction, class_name: "Transaction", foreign_key: "transaction_id", optional: true

  ENTRY_TYPES = %w[debit credit].freeze

  validates :entry_type, presence: true, inclusion: { in: ENTRY_TYPES }
  validates :amount_cents, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :currency, presence: true, length: { is: 3 }
  validates :correlation_id, presence: true

  scope :debits, -> { where(entry_type: "debit") }
  scope :credits, -> { where(entry_type: "credit") }
  scope :for_correlation, ->(id) { where(correlation_id: id) }

  monetize :amount_cents, as: :amount, with_model_currency: :currency

  def debit?
    entry_type == "debit"
  end

  def credit?
    entry_type == "credit"
  end
end
