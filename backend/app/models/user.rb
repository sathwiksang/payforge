class User < ApplicationRecord
  include Auditable

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :lockable, :timeoutable,
         :two_factor_authenticatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  belongs_to :merchant, optional: true

  ROLES = %w[super_admin admin manager analyst viewer].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :password, length: { minimum: 12 }, if: :password_required?

  def admin?
    role.in?(%w[super_admin admin])
  end

  def manager?
    role.in?(%w[super_admin admin manager])
  end

  private

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end
end
