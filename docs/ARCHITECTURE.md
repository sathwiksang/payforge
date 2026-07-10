# Architecture

## System overview

PayForge is a modular-monolith payment platform: a Rails 8 API-only backend
(event-sourced transactions, double-entry ledger, saga-based lifecycle,
LightGBM fraud scoring via ONNX) with a Next.js 16 BFF frontend, Sidekiq
workers on Redis, and PostgreSQL.

```
                   ┌────────────────────── EC2 portfolio-host ──────────────────────┐
                   │                                                                │
 Internet ─ 443 ─► Caddy ── payforge.….dev ─────► Next.js BFF (:3000)               │
                   │  └──── payforge-api.….dev ─► Rails 8 API (:80) ◄─ browser calls │
                   │                                │        (CORS allowlist)       │
                   │                                ├─► PostgreSQL 17               │
                   │                                ├─► Redis 7 (Sidekiq + streams) │
                   │                                └─► Sidekiq worker container    │
                   └────────────────────────────────────────────────────────────────┘
```

The frontend calls the API directly from the browser; the public API URL is
baked into the client bundle at image build (`--build-arg NEXT_PUBLIC_API_URL`),
and the API's CORS allowlist admits the frontend origin.

## Decision records

The significant choices are captured as ADRs — start here:

| ADR | Decision |
|---|---|
| [001](adr/001-event-sourcing-for-transactions.md) | Event sourcing for transactions |
| [002](adr/002-lightgbm-over-deep-learning.md) | LightGBM over deep learning for fraud |
| [003](adr/003-modular-monolith-over-microservices.md) | Modular monolith over microservices |
| [004](adr/004-redis-streams-over-kafka.md) | Redis Streams over Kafka |
| [005](adr/005-client-side-tokenization-pci.md) | Client-side tokenization (PCI scope) |
| [006](adr/006-property-based-testing-for-ledger.md) | Property-based testing for the ledger |
| [007](adr/007-onnx-runtime-for-ruby-inference.md) | ONNX runtime for Ruby inference |
| [008](adr/008-double-entry-accounting-design.md) | Double-entry accounting design |
| [009](adr/009-saga-over-two-phase-commit.md) | Sagas over two-phase commit |
| [010](adr/010-next-js-bff-pattern.md) | Next.js BFF pattern |

## Production notes

- Background jobs: **Sidekiq** (`payforge-sidekiq` container, same image as the
  API). Rails cache is in-process `memory_store`; Redis serves Sidekiq and
  streams. (The Rails-default Solid Queue/Cache production config was removed —
  those gems are not in the bundle.)
- Databases: `payforge_production` (+`_cache/_queue/_cable`, unused by the
  Sidekiq setup but kept schema-compatible), role `payforge`.
- Eager loading is exercised in CI (`zeitwerk:check`) — this catches
  association-name conflicts and autoload issues that dev lazy-loading hides.
