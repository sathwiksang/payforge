class TransactionBlueprint < Blueprinter::Base
  identifier :id

  fields :merchant_id, :status, :currency, :idempotency_key,
         :fraud_score, :fraud_decision, :card_last_four, :card_brand,
         :authorization_code

  field :amount do |tx|
    {
      cents: tx.amount_cents,
      currency: tx.currency,
      formatted: format_currency(tx.amount_cents, tx.currency)
    }
  end

  field :fee_cents
  field :net_cents

  field :created_at do |tx|
    tx.created_at.iso8601
  end

  view :list do
    excludes :authorization_code
  end

  view :detailed do
    field :authorized_at do |tx|
      tx.authorized_at&.iso8601
    end

    field :captured_at do |tx|
      tx.captured_at&.iso8601
    end

    field :settled_at do |tx|
      tx.settled_at&.iso8601
    end

    field :refunded_at do |tx|
      tx.refunded_at&.iso8601
    end

    field :failed_at do |tx|
      tx.failed_at&.iso8601
    end
  end

  view :full do
    include_view :detailed

    field :events do |tx|
      stream = Rails.configuration.event_store.read.stream("Payment$#{tx.id}").to_a
      stream.map do |event|
        {
          type: event.event_type,
          data: event.data,
          timestamp: event.metadata[:timestamp]&.iso8601 || event.metadata.fetch(:timestamp, nil)
        }
      end
    end

    field :ledger_entries do |tx|
      tx.ledger_entries.order(created_at: :asc).map do |entry|
        {
          id: entry.id,
          debit_account: entry.debit_account_id,
          credit_account: entry.credit_account_id,
          amount_cents: entry.amount_cents,
          currency: entry.currency,
          entry_type: entry.entry_type,
          created_at: entry.created_at.iso8601
        }
      end
    end
  end

  private

  def self.format_currency(cents, currency)
    dollars = cents / 100.0
    "$#{'%.2f' % dollars}" # Simple USD format
  end
end
