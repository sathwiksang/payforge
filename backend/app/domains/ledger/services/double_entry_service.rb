module Ledger
  module Services
    class DoubleEntryService
      class InsufficientBalanceError < StandardError; end
      class InvalidTransferError < StandardError; end
      class IdempotencyViolation < StandardError; end

      ALLOWED_TRANSFERS = {
        payment_authorized: { from: [:settlement, :asset], to: [:processing, :asset] },
        payment_captured:   { from: [:processing, :asset], to: [:available, :asset] },
        fee_extracted:      { from: [:processing, :asset], to: [:fees_collected, :revenue] },
        payment_refunded:   { from: [:available, :asset],  to: [:settlement, :asset] },
        fee_refunded:       { from: [:fees_collected, :revenue], to: [:settlement, :asset] },
        dispute_opened:     { from: [:available, :asset],  to: [:reserve, :asset] },
        dispute_resolved:   { from: [:reserve, :asset],    to: [:available, :asset] },
        dispute_lost:       { from: [:reserve, :asset],    to: [:settlement, :asset] }
      }.freeze

      def record_authorization(transaction:)
        transfer(
          amount_cents: transaction.amount_cents,
          currency: transaction.currency,
          from_scope: :settlement,
          from_type: :asset,
          to_scope: :processing,
          to_type: :asset,
          merchant: transaction.merchant,
          code: :payment_authorized,
          transaction: transaction,
          description: "Authorization for #{transaction.amount_cents} cents"
        )
      end

      def record_capture(transaction:)
        ActiveRecord::Base.transaction do
          transfer(
            amount_cents: transaction.net_cents,
            currency: transaction.currency,
            from_scope: :processing,
            from_type: :asset,
            to_scope: :available,
            to_type: :asset,
            merchant: transaction.merchant,
            code: :payment_captured,
            transaction: transaction,
            description: "Capture net #{transaction.net_cents} cents"
          )

          transfer(
            amount_cents: transaction.fee_cents,
            currency: transaction.currency,
            from_scope: :processing,
            from_type: :asset,
            to_scope: :fees_collected,
            to_type: :revenue,
            merchant: transaction.merchant,
            code: :fee_extracted,
            transaction: transaction,
            description: "Fee extraction #{transaction.fee_cents} cents"
          )
        end
      end

      def record_refund(transaction:, amount_cents: nil)
        refund_amount = amount_cents || transaction.net_cents
        raise ArgumentError, "Refund amount must be positive" unless refund_amount.positive?

        transfer(
          amount_cents: refund_amount,
          currency: transaction.currency,
          from_scope: :available,
          from_type: :asset,
          to_scope: :settlement,
          to_type: :asset,
          merchant: transaction.merchant,
          code: :payment_refunded,
          transaction: transaction,
          description: "Refund #{refund_amount} cents"
        )
      end

      def record_dispute_opened(transaction:)
        remaining_available = transaction.net_cents - total_refunded_for(transaction)
        return if remaining_available <= 0

        transfer(
          amount_cents: remaining_available,
          currency: transaction.currency,
          from_scope: :available,
          from_type: :asset,
          to_scope: :reserve,
          to_type: :asset,
          merchant: transaction.merchant,
          code: :dispute_opened,
          transaction: transaction,
          description: "Dispute hold #{remaining_available} cents"
        )
      end

      def record_dispute_resolved(transaction:)
        reserve_account = resolve_account(:reserve, :asset, transaction.currency, transaction.merchant)
        return if reserve_account.balance_cents <= 0

        transfer(
          amount_cents: reserve_account.balance_cents,
          currency: transaction.currency,
          from_scope: :reserve,
          from_type: :asset,
          to_scope: :available,
          to_type: :asset,
          merchant: transaction.merchant,
          code: :dispute_resolved,
          transaction: transaction,
          description: "Dispute resolved, funds released"
        )
      end

      def record_dispute_lost(transaction:)
        reserve_account = resolve_account(:reserve, :asset, transaction.currency, transaction.merchant)
        return if reserve_account.balance_cents <= 0

        transfer(
          amount_cents: reserve_account.balance_cents,
          currency: transaction.currency,
          from_scope: :reserve,
          from_type: :asset,
          to_scope: :settlement,
          to_type: :asset,
          merchant: transaction.merchant,
          code: :dispute_lost,
          transaction: transaction,
          description: "Dispute lost, funds returned to network"
        )
      end

      def verify_balance_integrity!
        total_debits = LedgerEntry.debits.sum(:amount_cents)
        total_credits = LedgerEntry.credits.sum(:amount_cents)

        unless total_debits == total_credits
          raise "CRITICAL: Ledger imbalance! Debits: #{total_debits}, Credits: #{total_credits}, " \
                "Difference: #{total_debits - total_credits} cents"
        end

        true
      end

      def balance_for(scope:, account_type:, currency: "USD", merchant: nil)
        account = resolve_account(scope, account_type, currency, merchant)
        account.balance_cents
      end

      private

      def transfer(amount_cents:, currency:, from_scope:, from_type:, to_scope:, to_type:,
                   merchant:, code:, transaction:, description: nil)
        validate_transfer!(code, from_scope, from_type, to_scope, to_type)
        raise ArgumentError, "Amount must be positive" unless amount_cents.positive?

        correlation_id = SecureRandom.uuid
        idempotency_key = "#{code}:#{transaction.id}:#{amount_cents}"

        from_merchant = platform_account?(from_scope) ? nil : merchant
        to_merchant = platform_account?(to_scope) ? nil : merchant

        ActiveRecord::Base.transaction do
          from_account = resolve_account(from_scope, from_type, currency, from_merchant)
          to_account = resolve_account(to_scope, to_type, currency, to_merchant)

          from_account.debit!(amount_cents)
          to_account.credit!(amount_cents)

          LedgerEntry.create!(
            account: from_account,
            payment_transaction: transaction,
            entry_type: "debit",
            amount_cents: amount_cents,
            currency: currency,
            description: description,
            correlation_id: correlation_id,
            metadata: { code: code, counterpart_account_id: to_account.id }
          )

          LedgerEntry.create!(
            account: to_account,
            payment_transaction: transaction,
            entry_type: "credit",
            amount_cents: amount_cents,
            currency: currency,
            description: description,
            correlation_id: correlation_id,
            metadata: { code: code, counterpart_account_id: from_account.id }
          )
        end
      end

      def validate_transfer!(code, from_scope, from_type, to_scope, to_type)
        spec = ALLOWED_TRANSFERS[code]
        raise InvalidTransferError, "Unknown transfer code: #{code}" unless spec

        expected_from = [from_scope.to_sym, from_type.to_sym]
        expected_to = [to_scope.to_sym, to_type.to_sym]

        unless spec[:from] == expected_from && spec[:to] == expected_to
          raise InvalidTransferError,
                "Transfer #{code} not allowed from #{from_scope}:#{from_type} to #{to_scope}:#{to_type}"
        end
      end

      def resolve_account(scope, account_type, currency, merchant)
        Account.find_or_create_for(
          scope: scope.to_s,
          account_type: account_type.to_s,
          currency: currency,
          merchant: merchant
        )
      end

      def platform_account?(scope)
        scope.to_s.in?(%w[settlement fees_collected transaction_fees])
      end

      def total_refunded_for(transaction)
        LedgerEntry.joins(:account)
                   .where(transaction_id: transaction.id, entry_type: "debit")
                   .where(accounts: { scope: "available" })
                   .where("ledger_entries.metadata->>'code' = ?", "payment_refunded")
                   .sum(:amount_cents)
      end
    end
  end
end
