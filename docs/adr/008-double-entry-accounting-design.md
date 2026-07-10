# ADR-008: Custom Double-Entry Accounting Design

**Status:** Accepted
**Date:** 2026-02-16

## Context

Payment processing requires tracking money flow across multiple accounts (merchant available balance, platform fees, settlement, processing holds, dispute reserves). We need a system that guarantees financial accuracy and auditability.

## Decision

Implement a custom double-entry bookkeeping system with: (1) 6 account types (settlement, processing, available, reserve, fees_collected, transaction_fees), (2) every financial movement creates balanced debit/credit pairs, (3) entries are append-only (corrections via reversing entries), (4) `verify_balance_integrity!` method that asserts total debits == total credits.

## Consequences

**Benefits:**
- Provably correct: the fundamental accounting equation (Assets = Liabilities + Equity) is enforced at every operation
- Complete audit trail: every cent is traceable through the ledger
- Append-only design prevents tampering with historical records
- Balance verification can run as a background job for continuous monitoring
- Supports partial captures, partial refunds, disputes, and fee splits

**Trade-offs:**
- More complex than a simple balance column — every operation creates 2-4 ledger entries
- Storage grows linearly with transaction volume (mitigated: entries are small)
- Balance queries require aggregation across entries (mitigated: accounts cache current balance)

## Alternatives Considered

1. **`double_entry` gem** — Pre-built solution but rigid transfer definitions. Our use case requires custom account scoping (per-merchant available balances, platform-wide fee collection) that the gem doesn't support well.
2. **Simple balance column** — Just increment/decrement a balance field. No audit trail, no proof of correctness, no way to detect errors.
3. **Third-party ledger service (Modern Treasury, Moov)** — Adds external dependency. Building it demonstrates deep understanding of financial systems.
