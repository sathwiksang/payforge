# ADR-003: Modular Monolith Over Microservices

**Status:** Accepted
**Date:** 2026-02-15

## Context

PayForge has 5 domains (Payments, Ledger, Fraud, Merchants, Webhooks) that need clear boundaries while maintaining transactional consistency for financial operations.

## Decision

Structure the application as a modular monolith with domain-driven boundaries under `app/domains/`. Each domain has its own models, services, events, and policies. Domains communicate through the event store, not direct method calls where possible.

## Consequences

**Benefits:**
- No network overhead between domains — critical for payment processing latency
- Database transactions span domains (e.g., payment capture + ledger recording are atomic)
- Single deployment, single database, simple operations
- Domain boundaries are clean enough to extract into services later
- Shared authentication and authorization infrastructure

**Trade-offs:**
- All domains must use the same language and framework
- A bug in one domain can crash the entire application
- Scaling requires scaling the entire monolith (horizontal scaling via multiple instances)

## Alternatives Considered

1. **Microservices** — Adds distributed transaction complexity (saga compensation across network boundaries), deployment overhead, and inter-service latency. Premature for a system that doesn't yet need independent scaling.
2. **Monolith without domain structure** — Leads to spaghetti dependencies. The domain structure provides the discipline of microservices without the infrastructure cost.
