class Merchant < ApplicationRecord
  include Auditable

  has_many :users, dependent: :destroy
  has_many :api_keys, dependent: :destroy
  has_many :transactions, dependent: :restrict_with_error
  has_many :accounts, dependent: :restrict_with_error

  encrypts :email_ciphertext
  blind_index :email, attribute: :email_ciphertext

  encrypts :webhook_url_ciphertext
  encrypts :webhook_secret_ciphertext

  validates :name, presence: true
  validates :email_ciphertext, presence: true
  validates :status, presence: true, inclusion: { in: %w[active suspended deactivated] }
  validates :fee_percentage, presence: true, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validates :fee_fixed_cents, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  scope :active, -> { where(status: "active") }

  RISK_TIERS = %w[standard elevated high].freeze

  validates :risk_tier, inclusion: { in: RISK_TIERS }

  def calculate_fee(amount_cents)
    percentage_fee = (amount_cents * fee_percentage / 100.0).ceil
    percentage_fee + fee_fixed_cents
  end

  def days_since_onboarding
    return 0 unless onboarded_at
    ((Time.current - onboarded_at) / 1.day).to_i
  end

  def risk_tier_encoding
    { "standard" => 0.0, "elevated" => 1.0, "high" => 2.0 }.fetch(risk_tier, 0.0)
  end
end
