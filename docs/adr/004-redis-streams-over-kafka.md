# ADR-004: Redis + Sidekiq Over Kafka for Async Processing

**Status:** Accepted
**Date:** 2026-02-15

## Context

PayForge needs async job processing for: webhook delivery (with retries), saga orchestration, and event subscriber processing. We need a reliable queue with retry semantics.

## Decision

Use Redis as the message broker with Sidekiq for job processing. Rails Event Store handles domain events in-process. Webhook retries use Sidekiq's retry mechanism with exponential backoff.

## Consequences

**Benefits:**
- Redis is already required for caching and rate limiting (Rack::Attack) — no additional infrastructure
- Sidekiq provides battle-tested retry semantics, dead letter queues, and monitoring UI
- Simple operational model: one Redis instance serves cache, queue, and rate limiting
- Sidekiq Cron handles scheduled jobs (stale transaction cleanup, settlement batching)

**Trade-offs:**
- Redis is not a durable message broker — jobs can be lost on Redis crash (mitigated by Redis persistence)
- No built-in partitioning or consumer groups (Kafka excels here)
- Sidekiq processes must run alongside the web server

## Alternatives Considered

1. **Apache Kafka** — Enterprise-grade durability and partitioning, but massive operational overhead for a single-application system. Would be the right choice if we had multiple services consuming events.
2. **RabbitMQ** — More message-broker-like semantics than Redis, but adds another infrastructure dependency without clear benefit over Sidekiq for our use case.
3. **Database-backed queue (GoodJob/Solid Queue)** — Simpler but higher latency. Redis-backed Sidekiq is faster for the webhook delivery latency requirements.
