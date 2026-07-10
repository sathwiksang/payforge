class TransactionPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    admin? || same_merchant?
  end

  def create?
    admin? || (manager? && same_merchant?)
  end

  # ABAC: attribute-based checks for refund authorization
  def refund?
    return false unless admin? || (manager? && same_merchant?)
    return false unless record.refundable?

    # Refund window: 90 days from capture
    return false if record.captured_at && record.captured_at < 90.days.ago

    true
  end

  def capture?
    return false unless admin? || (manager? && same_merchant?)
    record.capturable?
  end

  def void?
    admin? || (manager? && same_merchant?)
  end

  def approve_fraud_case?
    admin? || fraud_analyst?
  end

  relation_scope do |relation|
    if admin?
      relation.all
    else
      relation.where(merchant_id: user.merchant_id)
    end
  end

  private

  def fraud_analyst?
    user&.role.in?(%w[super_admin admin analyst])
  end

  def refund_limit_for_role
    case user&.role
    when "super_admin" then Float::INFINITY
    when "admin" then Float::INFINITY
    when "manager" then 100_000  # $1,000
    when "analyst" then 25_000   # $250
    else 0
    end
  end
end
