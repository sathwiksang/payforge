module Api
  module V1
    class TransactionsController < BaseController
      before_action :authenticate_user!
      before_action :set_merchant
      before_action :set_transaction, only: [:show, :capture, :refund, :void, :events, :ledger]

      # GET /api/v1/transactions
      def index
        authorize! Transaction
        scope = authorized_scope(Transaction.all, type: :active_record_relation).recent
        scope = scope.by_status(params[:status]) if params[:status].present?
        scope = scope.where("amount_cents >= ?", params[:min_amount].to_i) if params[:min_amount].present?
        scope = scope.where("amount_cents <= ?", params[:max_amount].to_i) if params[:max_amount].present?
        scope = scope.where("created_at >= ?", Time.zone.parse(params[:from])) if params[:from].present?
        scope = scope.where("created_at <= ?", Time.zone.parse(params[:to])) if params[:to].present?

        render_paginated(scope, TransactionBlueprint, view: :list)
      end

      # GET /api/v1/transactions/:id
      def show
        authorize! @transaction
        render_success(TransactionBlueprint.render_as_hash(@transaction, view: :detailed))
      end

      # POST /api/v1/transactions
      def create
        transaction = @merchant.transactions.build(create_params)
        transaction.status = "pending"
        authorize! transaction

        if transaction.save
          Payments::Sagas::PaymentLifecycleSaga.perform_async(transaction.id)
          render_created(
            TransactionBlueprint.render_as_hash(transaction, view: :detailed),
            meta: { idempotency_key: transaction.idempotency_key }
          )
        else
          render_error(
            "Transaction creation failed",
            code: "validation_error",
            param: transaction.errors.attribute_names.first&.to_s
          )
        end
      end

      # POST /api/v1/transactions/:id/capture
      def capture
        authorize! @transaction
        unless @transaction.capturable?
          return render_conflict("Transaction not capturable (status: #{@transaction.status})")
        end

        capture_amount = params[:amount_cents]&.to_i || @transaction.amount_cents

        aggregate = load_aggregate(@transaction.id)
        aggregate.capture(amount_cents: capture_amount)
        store_aggregate(aggregate, @transaction.id)

        ledger = Ledger::Services::DoubleEntryService.new
        @transaction.reload
        ledger.record_capture(transaction: @transaction)

        @transaction.reload
        render_success(TransactionBlueprint.render_as_hash(@transaction, view: :detailed))
      rescue Payments::Aggregates::PaymentAggregate::InvalidTransition => e
        render_conflict(e.message)
      end

      # POST /api/v1/transactions/:id/refund
      def refund
        authorize! @transaction
        unless @transaction.refundable?
          return render_conflict("Transaction not refundable (status: #{@transaction.status})")
        end

        refund_amount = params[:amount_cents]&.to_i || @transaction.net_cents

        aggregate = load_aggregate(@transaction.id)
        aggregate.refund(amount_cents: refund_amount)
        store_aggregate(aggregate, @transaction.id)

        ledger = Ledger::Services::DoubleEntryService.new
        @transaction.reload
        ledger.record_refund(transaction: @transaction, amount_cents: refund_amount)

        if @transaction.merchant.webhook_url_ciphertext.present?
          Webhooks::Services::WebhookDeliveryService.new.deliver_payment_refunded(
            @transaction, refund_amount_cents: refund_amount
          )
        end

        @transaction.reload
        render_success(TransactionBlueprint.render_as_hash(@transaction, view: :detailed))
      rescue ArgumentError => e
        render_error(e.message, code: "invalid_refund_amount")
      rescue Payments::Aggregates::PaymentAggregate::InvalidTransition => e
        render_conflict(e.message)
      end

      # POST /api/v1/transactions/:id/void
      def void
        authorize! @transaction
        aggregate = load_aggregate(@transaction.id)
        aggregate.void
        store_aggregate(aggregate, @transaction.id)

        @transaction.reload
        render_success(TransactionBlueprint.render_as_hash(@transaction, view: :detailed))
      rescue Payments::Aggregates::PaymentAggregate::InvalidTransition => e
        render_conflict(e.message)
      end

      # GET /api/v1/transactions/:id/events
      def events
        authorize! @transaction, to: :show?
        stream = Rails.configuration.event_store.read.stream("Payment$#{@transaction.id}").to_a
        event_data = stream.map do |event|
          {
            type: event.event_type,
            data: event.data,
            timestamp: event.metadata[:timestamp]
          }
        end
        render_success(event_data)
      end

      # GET /api/v1/transactions/:id/ledger
      def ledger
        authorize! @transaction, to: :show?
        entries = @transaction.ledger_entries.order(created_at: :asc).map do |entry|
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
        render_success(entries)
      end

      private

      def set_merchant
        @merchant = current_user.merchant
        render_error("No merchant associated", status: :forbidden, code: "no_merchant") unless @merchant
      end

      def set_transaction
        @transaction = @merchant.transactions.find(params[:id])
      end

      def create_params
        params.require(:transaction).permit(
          :amount_cents, :currency, :card_last_four, :card_brand,
          :card_token, :idempotency_key, metadata: {}
        )
      end

      def load_aggregate(id)
        aggregate = Payments::Aggregates::PaymentAggregate.new(id)
        stream = Rails.configuration.event_store.read.stream("Payment$#{id}").to_a
        stream.each { |event| aggregate.apply(event) } if stream.any?
        aggregate
      end

      def store_aggregate(aggregate, transaction_id)
        unpublished = aggregate.unpublished_events.to_a
        return if unpublished.empty?

        unpublished.each do |event|
          Rails.configuration.event_store.publish(event, stream_name: "Payment$#{transaction_id}")
        end
      end
    end
  end
end
