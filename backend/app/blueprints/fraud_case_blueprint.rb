class FraudCaseBlueprint < Blueprinter::Base
  identifier :id

  fields :status, :priority, :risk_score, :decision, :model_used

  field :transaction_id
  field :merchant_id

  field :created_at do |fc|
    fc.created_at.iso8601
  end

  view :detailed do
    field :reviewer_id
    field :notes

    field :reviewed_at do |fc|
      fc.reviewed_at&.iso8601
    end

    field :resolved_at do |fc|
      fc.resolved_at&.iso8601
    end

    field :transaction do |fc|
      TransactionBlueprint.render_as_hash(fc.payment_transaction, view: :list)
    end
  end
end
