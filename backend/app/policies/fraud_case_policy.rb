class FraudCasePolicy < ApplicationPolicy
  def index?
    admin? || fraud_analyst?
  end

  def show?
    admin? || fraud_analyst? || same_merchant?
  end

  def review?
    admin? || fraud_analyst?
  end

  def resolve?
    admin? || fraud_analyst?
  end

  def escalate?
    admin?
  end

  relation_scope do |relation|
    if admin? || fraud_analyst?
      relation.all
    else
      relation.where(merchant_id: user.merchant_id)
    end
  end

  private

  def fraud_analyst?
    user&.role.in?(%w[super_admin admin analyst])
  end
end
