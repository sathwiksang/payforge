# PayForge FAQ

## General

### What is PayForge?
PayForge is a production-grade payment processing platform with integrated fraud intelligence. It demonstrates enterprise patterns: event sourcing, CQRS, double-entry bookkeeping, ML-powered fraud detection, and a versioned REST API with interactive documentation.

### Is this a real payment processor?
No. PayForge simulates the architecture and logic of a real payment processor but does not connect to actual card networks. The gateway client returns simulated responses. All other components (ledger, fraud scoring, event sourcing, webhooks) are fully functional.

### Can I use real credit cards?
No. PayForge uses test card tokens (e.g., `tok_visa_4242`). No real card data is ever collected or processed.

### Why build this?
To demonstrate senior-level backend engineering: domain-driven design, financial-grade data integrity, ML integration, comprehensive testing, and production security posture — all in a single cohesive system.

## Architecture

### Why event sourcing?
Every payment state change is captured as an immutable event. This provides: (1) a complete audit trail required for financial compliance, (2) the ability to replay events to rebuild state, (3) temporal queries ("what was the state at time T?"), and (4) decoupled subscribers that react to domain events asynchronously.

### Why CQRS?
Separating commands (writes) from queries (reads) allows us to optimize each independently. Write models enforce business rules through aggregates and sagas. Read models are optimized projections for API queries and dashboards. This is essential when write and read patterns differ significantly, which they do in payment processing.

### Why a modular monolith instead of microservices?
Microservices add network latency, distributed transaction complexity, and operational overhead. A modular monolith gives us domain isolation (each module has its own models, services, and policies) without the infrastructure cost. The domain boundaries are clean enough to extract into services later if scale demands it.

### Why Rails for FinTech?
Rails provides: (1) ActiveRecord for rapid modeling with strong migration tooling, (2) a mature ecosystem (Devise, Sidekiq, PaperTrail), (3) Rails Event Store for event sourcing, (4) excellent testing infrastructure. Ruby's expressiveness makes domain logic readable. Performance-critical paths (ML inference) use native C extensions.

### How does the saga pattern work?
The PaymentLifecycleSaga orchestrates multi-step payment processing: initiate → authorize → fraud check → capture. If any step fails, compensation actions run (e.g., void the authorization). Each step publishes domain events, ensuring the system remains consistent even on partial failure.

## Fraud Detection

### How does the ML scoring work?
Every transaction is scored in two phases: (1) A rule engine applies deterministic checks (velocity, amount thresholds, time-of-day, first-transaction checks). If any critical rule triggers, the transaction is hard-blocked immediately. (2) A LightGBM model predicts fraud probability using extracted features (amount ratios, velocity metrics, merchant history). The final score (0.0–1.0) determines the decision: pass (<0.60), review (0.60–0.85), or block (>0.85).

### What is SHAP?
SHAP (SHapley Additive exPlanations) is a game-theoretic approach to explain ML model predictions. For each transaction, SHAP shows which features pushed the score up or down (e.g., "unusual amount +0.15", "established customer -0.08"). This makes fraud decisions transparent and auditable, which is critical for regulatory compliance.

### Why LightGBM over deep learning?
LightGBM offers: (1) sub-millisecond inference in Ruby via native bindings, (2) small model files (~2MB vs hundreds of MB for neural networks), (3) excellent performance on tabular data (fraud features are tabular), (4) interpretability via SHAP (deep learning SHAP is orders of magnitude slower), (5) fast training on modest hardware. Deep learning would be overkill for this feature set.

### What features does the model use?
The FeatureExtractor computes: transaction amount, amount relative to merchant average, card velocity (1h, 24h), merchant transaction count, chargeback rate, merchant age, time-of-day, day-of-week, and whether the card has prior history with the merchant.

### How accurate is the model?
The LightGBM model achieves AUC 1.0 on the synthetic training data (200K samples, 2% fraud rate, 5-fold cross-validation). Real-world performance would differ, but the architecture supports model retraining and A/B testing.

## Security

### Is this PCI compliant?
PayForge is PCI DSS 4.0-aware: card data is tokenized (never stored as plaintext), PII is encrypted with Lockbox (AES-256-GCM), all API endpoints require authentication, and security headers are configured via secure_headers. However, full PCI compliance requires infrastructure-level controls (network segmentation, penetration testing, etc.) that are out of scope for a demo project.

### How is data encrypted?
Three layers: (1) Transport — TLS for all API traffic, (2) Application — Lockbox encrypts PII fields (merchant email) with AES-256-GCM, with blind indexes for searchable encryption, (3) Database — PostgreSQL encryption at rest. Secrets are managed via Rails credentials, never committed to source control.

### What about SQL injection?
Rails' ActiveRecord ORM parameterizes all queries by default. Brakeman static analysis scans for injection vulnerabilities on every build. The project maintains 0 Brakeman warnings.

### How is authorization handled?
Action Policy provides role-based access control with 4 roles: Viewer (read-only), Manager (+ payment operations), Admin (+ user/key management), Super Admin (+ merchant management). Every controller action calls `authorize!` before accessing resources. Scopes ensure merchants can only see their own data.

## Testing

### What is property-based testing?
Instead of writing specific test cases, property-based tests define invariants ("debits always equal credits") and verify them against hundreds of randomly generated inputs. This catches edge cases that hand-written tests miss. PayForge uses Rantly to generate random amounts, fee structures, and transaction sequences.

### What is mutation testing?
Mutation testing systematically modifies your code (flips operators, changes return values, removes guards) and verifies your tests catch every change. If a mutant "survives" (tests still pass), you have a blind spot. PayForge has mutation-equivalent tests that explicitly target these patterns: operator flips, boundary conditions, removed nil checks, swapped arguments.

### Why so many test types?
Each test type catches different classes of bugs: Unit tests catch logic errors. Integration tests catch interaction bugs. Property-based tests catch invariant violations on random inputs. Mutation tests catch undertested code paths. Contract tests catch API schema drift. Security tests catch OWASP vulnerabilities. Together they provide defense-in-depth for a financial system.

### What's the test coverage?
418+ tests across 7 categories: unit, integration, property-based, mutation-equivalent, contract, security, and API request specs. Line coverage exceeds 90% on critical domain modules.

## Technology

### Can it scale?
The modular monolith architecture handles significant load: PostgreSQL with proper indexing, Redis caching, Sidekiq for async processing, and connection pooling. For higher scale: extract the fraud scoring engine as a separate service, add read replicas for query load, and use Redis Streams for event delivery. The domain boundaries are already clean enough for extraction.

### Why not Go/Rust?
Ruby/Rails optimizes for developer productivity and domain expressiveness. The performance-critical path (ML inference) uses LightGBM's C backend. For a platform where correctness matters more than raw throughput, Rails' mature ecosystem (testing, ORM, background jobs) provides more value than systems-language performance.

## Running

### System requirements?
- Ruby >= 3.3, Node.js >= 18, Python >= 3.10
- PostgreSQL 14+, Redis 6+
- ~2GB disk space (including ML model and dependencies)

### How to reset the database?
```bash
cd backend
bin/rails db:drop db:create db:migrate db:seed
```

### How to add test data?
```bash
cd backend
bin/rails db:seed  # Creates merchants, transactions, fraud cases
```

### How to run just the backend API?
```bash
cd backend
bin/rails server -p 3200
# API available at http://localhost:3200/api/v1/
```

## Interview Context

### What did you learn building this?
Event sourcing and CQRS require careful thinking about eventual consistency and command/query separation. Double-entry bookkeeping is deceptively simple in concept but requires meticulous implementation to maintain balance invariants. ML model integration in production requires graceful degradation, not just happy-path inference.

### What would you change?
(1) Add a proper message bus (Kafka/Redis Streams) instead of direct event store subscriptions for better scaling. (2) Implement a card vault microservice for true PCI scope reduction. (3) Add more sophisticated fraud features (device fingerprinting, behavioral biometrics). (4) Implement settlement batching and merchant payouts.

### How did AI help?
AI was used as a coding assistant for boilerplate generation, test scaffolding, and documentation. All architectural decisions, domain logic, and financial invariants were designed and verified by hand. The test suite — particularly the property-based and mutation-equivalent tests — serves as a verification layer independent of how the code was written.
