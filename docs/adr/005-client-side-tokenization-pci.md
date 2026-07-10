# ADR-005: Client-Side Tokenization for PCI Scope Reduction

**Status:** Accepted
**Date:** 2026-02-20

## Context

Handling raw card numbers (PANs) puts the entire system in PCI DSS scope. We need to minimize the surface area that handles sensitive card data.

## Decision

Card data is tokenized before reaching the backend. The backend only stores `card_last_four` and `card_brand` for display purposes, plus a `card_token` for gateway interactions. The token is a reference to the card data stored in the (simulated) gateway vault.

## Consequences

**Benefits:**
- Backend never sees or stores full card numbers — dramatically reduces PCI scope
- Only `card_last_four` is stored, which is not considered cardholder data under PCI DSS
- Merchant email and other PII is encrypted with Lockbox (AES-256-GCM) for defense in depth

**Trade-offs:**
- Card operations (recurring charges, updates) require the token to still be valid at the gateway
- Token lifecycle management adds complexity for long-lived subscriptions
- In this demo, tokenization is simulated — a production system would integrate with a real vault (Stripe, Adyen, or a dedicated card vault service)

## Alternatives Considered

1. **Store encrypted card numbers** — Even encrypted PANs put the database in PCI scope. Tokenization is strictly better for scope reduction.
2. **Proxy architecture** — Route all card data through a PCI-compliant proxy (e.g., Basis Theory). Valid for production but adds infrastructure dependency.
