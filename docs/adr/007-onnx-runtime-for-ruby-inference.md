# ADR-007: Native Ruby ML Inference (LightGBM + ONNX Runtime)

**Status:** Accepted
**Date:** 2026-02-18

## Context

The fraud scoring engine needs to run ML predictions in the Ruby backend process. We need a way to load Python-trained models and run inference without calling an external service for every transaction.

## Decision

Support two inference backends: (1) LightGBM's native Ruby gem for direct model loading from text files, and (2) ONNX Runtime for models exported to the ONNX format. The engine tries ONNX first (faster, more portable), then falls back to LightGBM native, then to rule-engine-only scoring.

## Consequences

**Benefits:**
- No network call for inference — sub-millisecond prediction latency
- Model files ship with the application — no external ML serving infrastructure
- Graceful degradation: if model loading fails, the rule engine provides baseline fraud detection
- ONNX format is framework-agnostic — models trained in any framework can be served

**Trade-offs:**
- Model updates require redeployment (no hot-swapping)
- Limited to models that can be exported to LightGBM text or ONNX format
- Native extensions (C bindings) can have platform-specific build issues

## Alternatives Considered

1. **Python sidecar for all inference** — Adds network latency (~5-10ms per call) and a deployment dependency. Used only for SHAP explanations where latency is less critical.
2. **TensorFlow Serving / TorchServe** — Production-grade ML serving but massive operational overhead for a single model.
3. **REST API to cloud ML service** — Adds external dependency, latency, and cost per prediction.
