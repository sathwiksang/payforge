class MerchantBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :status, :risk_tier, :fee_percentage, :fee_fixed_cents

  field :created_at do |m|
    m.created_at.iso8601
  end

  field :onboarded_at do |m|
    m.onboarded_at&.iso8601
  end

  view :profile do
    field :email do |m|
      m.email_ciphertext
    end

    field :webhook_url do |m|
      m.webhook_url_ciphertext.present? ? "configured" : nil
    end

    field :transaction_count do |m|
      m.transactions.count
    end
  end

  view :analytics do
    include_view :profile

    field :analytics do |m|
      transactions = m.transactions
      captured = transactions.where(status: "captured")
      {
        total_volume_cents: captured.sum(:amount_cents),
        total_revenue_cents: captured.sum(:fee_cents),
        transaction_count: transactions.count,
        fraud_rate: transactions.count > 0 ? transactions.where(fraud_decision: "block").count.to_f / transactions.count : 0,
        avg_transaction_cents: captured.count > 0 ? (captured.sum(:amount_cents) / captured.count) : 0
      }
    end
  end
end
