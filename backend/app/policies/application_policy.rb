class ApplicationPolicy < ActionPolicy::Base
  authorize :user, allow_nil: true
  authorize :merchant, allow_nil: true

  def admin?
    user&.admin?
  end

  def manager?
    user&.manager?
  end

  def same_merchant?
    return false unless user&.merchant_id && record.respond_to?(:merchant_id)
    user.merchant_id == record.merchant_id
  end
end
