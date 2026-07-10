# ADR-001: Event Sourcing for Transactions

**Status:** Accepted
**Date:** 2026-02-15

## Context

Payment transactions go through multiple state transitions (initiated, authorized, captured, settled, refunded). We need a complete audit trail of every state change for financial compliance, debugging, and dispute resolution.

## Decision

Use Rails Event Store to implement event sourcing for the payments domain. Every state change is captured as an immutable domain event (PaymentInitiated, PaymentAuthorized, PaymentCaptured, etc.). The current state is derived by replaying the event stream for a given aggregate.

## Consequences

**Benefits:**
- Complete audit trail for every payment — every state change is permanently recorded
- Temporal queries: reconstruct the state of any payment at any point in time
- Decoupled subscribers: fraud scoring, webhook delivery, and ledger recording all subscribe to events independently
- Event replay enables rebuilding read models without data loss

**Trade-offs:**
- Eventual consistency between write and read models requires careful handling
- Event schema evolution requires versioning strategy
- Higher storage requirements (events are append-only, never deleted)
- More complex debugging when tracing through event handlers

## Alternatives Considered

1. **State machine with audit log** — Simpler but doesn't support event replay or temporal queries. Audit log is a secondary concern rather than the source of truth.
2. **Database triggers** — Database-level auditing is opaque to application logic and doesn't support domain events or subscriber patterns.
