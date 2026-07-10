require "bcrypt"

class ApiKey < ApplicationRecord
  include Auditable

  belongs_to :merchant

  validates :name, presence: true
  validates :key_digest, presence: true, uniqueness: true
  validates :key_prefix, presence: true
  validates :environment, presence: true, inclusion: { in: %w[test live] }

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :for_environment, ->(env) { where(environment: env) }

  def self.authenticate(raw_key)
    return nil if raw_key.blank?

    prefix = raw_key[0..7]
    candidates = where(key_prefix: prefix).active
    candidates.find { |key| key.key_matches?(raw_key) }
  end

  def key_matches?(raw_key)
    BCrypt::Password.new(key_digest) == raw_key
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def self.generate_for(merchant:, name:, environment: "test")
    raw_key = "pk_#{environment}_#{SecureRandom.hex(24)}"
    key = create!(
      merchant: merchant,
      name: name,
      environment: environment,
      key_prefix: raw_key[0..7],
      key_digest: BCrypt::Password.create(raw_key)
    )
    [key, raw_key]
  end
end
