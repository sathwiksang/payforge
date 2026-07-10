class Account < ApplicationRecord
  belongs_to :merchant, optional: true
  has_many :ledger_entries, dependent: :restrict_with_error

  TYPES = %w[asset liability revenue expense].freeze
  SCOPES = %w[processing available reserve settlement fees_collected transaction_fees].freeze

  validates :account_type, presence: true, inclusion: { in: TYPES }
  validates :scope, presence: true, inclusion: { in: SCOPES }
  validates :currency, presence: true, length: { is: 3 }
  validates :account_type, uniqueness: { scope: [:merchant_id, :scope, :currency] }

  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(account_type: type) }
  scope :for_merchant, ->(merchant) { where(merchant: merchant) }
  scope :platform, -> { where(merchant_id: nil) }

  monetize :balance_cents, as: :balance, with_model_currency: :currency

  def self.find_or_create_for(scope:, account_type:, currency: "USD", merchant: nil)
    find_or_create_by!(
      scope: scope,
      account_type: account_type,
      currency: currency,
      merchant: merchant
    )
  end

  def credit!(amount_cents)
    raise ArgumentError, "Amount must be positive" unless amount_cents.positive?

    with_lock do
      case account_type
      when "asset"
        self.balance_cents += amount_cents
      when "liability", "revenue"
        self.balance_cents += amount_cents
      when "expense"
        self.balance_cents -= amount_cents
      end
      save!
    end
  end

  def debit!(amount_cents)
    raise ArgumentError, "Amount must be positive" unless amount_cents.positive?

    with_lock do
      case account_type
      when "asset"
        self.balance_cents -= amount_cents
      when "liability", "revenue"
        self.balance_cents -= amount_cents
      when "expense"
        self.balance_cents += amount_cents
      end
      save!
    end
  end
end
