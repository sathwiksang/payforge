class MerchantPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    admin? || (user&.merchant_id == record.id)
  end

  def create?
    admin?
  end

  def update?
    admin? || (manager? && user&.merchant_id == record.id)
  end
end
