# ADR-002: LightGBM Over Deep Learning for Fraud Detection

**Status:** Accepted
**Date:** 2026-02-18

## Context

We need a machine learning model for real-time fraud scoring. The model must: (1) score transactions in under 10ms, (2) provide interpretable explanations for each score, (3) run in the Ruby backend process without GPU infrastructure, (4) be small enough to deploy alongside the application.

## Decision

Use LightGBM (gradient boosted decision trees) for fraud scoring, with SHAP for post-hoc explanations. The model is trained in Python and exported as a text file, then loaded in Ruby via the `lightgbm` gem for native inference.

## Consequences

**Benefits:**
- Sub-millisecond inference in Ruby via C bindings (~0.1ms per prediction)
- Small model file (~2MB) ships with the application
- Excellent performance on tabular fraud features (AUC 1.0 on synthetic data)
- SHAP explanations are fast and well-supported for tree-based models
- No GPU or external ML infrastructure required

**Trade-offs:**
- Less suitable for unstructured data (text, images) if future features require it
- Feature engineering is manual (no automatic feature learning like neural networks)
- Model retraining requires Python environment

## Alternatives Considered

1. **Deep learning (PyTorch/TensorFlow)** — Higher latency (10-50ms), requires GPU for training, SHAP explanations are orders of magnitude slower, model files are 100x larger. Overkill for tabular features.
2. **Rules-only engine** — Simpler but misses complex fraud patterns. Rules serve as guardrails alongside the ML model.
3. **Third-party fraud API** — Adds external dependency, network latency, and cost. Doesn't demonstrate ML engineering capability.
