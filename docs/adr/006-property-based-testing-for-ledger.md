# ADR-006: Property-Based Testing for Financial Invariants

**Status:** Accepted
**Date:** 2026-02-22

## Context

The double-entry ledger must maintain the invariant that total debits always equal total credits, regardless of the sequence or values of transactions processed. Hand-written test cases only cover specific scenarios we think of.

## Decision

Use property-based testing (Rantly) to verify financial invariants against hundreds of randomly generated inputs. Key invariants tested: (1) debits == credits after any transaction sequence, (2) fee + net == amount for any fee structure, (3) refund never exceeds captured amount, (4) processing account returns to zero after capture.

## Consequences

**Benefits:**
- Catches edge cases that hand-written tests miss (extreme amounts, unusual fee percentages, boundary values)
- Invariants are tested against 50-100 random inputs per property, providing high confidence
- Documents the system's guarantees as executable specifications
- Particularly valuable for financial code where off-by-one errors have monetary consequences

**Trade-offs:**
- Slower than unit tests (100 iterations per property)
- Random failures can be hard to reproduce (mitigated by seed-based randomization)
- Requires thinking in properties rather than examples — different skill set

## Alternatives Considered

1. **Exhaustive example-based tests** — Would need hundreds of hand-written cases to approach the coverage of 100 random iterations. Not maintainable.
2. **Formal verification (TLA+, Alloy)** — Mathematically stronger guarantees but doesn't test the actual implementation, only the specification. Property-based tests verify the running code.
