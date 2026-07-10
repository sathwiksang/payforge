# ADR-009: Saga Pattern Over Two-Phase Commit

**Status:** Accepted
**Date:** 2026-02-17

## Context

Payment processing involves multiple steps that must complete atomically: authorization, fraud check, capture, ledger recording, webhook delivery. If any step fails, prior steps must be compensated (e.g., void an authorization if fraud check blocks the payment).

## Decision

Use the saga pattern (orchestration style) via `PaymentLifecycleSaga`. The saga coordinates each step sequentially, publishing domain events at each transition. On failure, compensation actions run in reverse order. The saga runs as a Sidekiq job for reliability.

## Consequences

**Benefits:**
- Each step is a local transaction — no distributed locks or two-phase commit coordination
- Compensation logic is explicit and testable
- Domain events published at each step enable other systems to react (webhooks, projections)
- Failed sagas are retried via Sidekiq with exponential backoff
- Partial failures leave the system in a known, consistent state

**Trade-offs:**
- Intermediate states are visible (a payment might be "authorized" for a few seconds before capture)
- Compensation can fail — `FailedCompensation` records track these for manual review
- More complex than a single database transaction spanning all operations

## Alternatives Considered

1. **Two-phase commit (2PC)** — Locks resources across the entire operation. High latency, poor scalability, complex failure recovery. Not suitable for payment processing where gateway calls can take seconds.
2. **Single large transaction** — All steps in one database transaction. Blocks for the duration of external calls (gateway, ML scoring). Timeouts would roll back all work.
3. **Choreography-based saga** — Events trigger the next step without a central coordinator. Harder to reason about, harder to debug, and harder to add compensation logic.
