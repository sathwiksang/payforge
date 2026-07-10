# PayForge

> Production-grade payment processing platform with integrated fraud intelligence.
> Event-sourced architecture, real-time ML scoring, double-entry ledger, PCI-aware security.

## Quick Start

```bash
git clone https://github.com/yourusername/payforge.git
cd payforge

# Backend
cd backend
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server -p 3200

# Frontend (new terminal)
cd frontend
npm install
npm run dev
```

Open http://localhost:3000 for the dashboard. Login with `admin@payforge.dev` / `PayForge2026!`

## Architecture

```
PayForge
├── backend/               Rails 8.1 API (Ruby 3.4)
│   ├── app/domains/       Domain-driven modules
│   │   ├── payments/      Payment lifecycle, aggregates, sagas
│   │   ├── ledger/        Double-entry bookkeeping
│   │   ├── fraud/         ML scoring engine, rule engine
│   │   ├── merchants/     Merchant management
│   │   └── webhooks/      Event delivery system
│   ├── app/controllers/   Versioned REST API (v1)
│   ├── app/policies/      Action Policy authorization
│   └── ml_models/         LightGBM fraud model
├── frontend/              Next.js 15 + TypeScript
│   ├── src/app/           Dashboard routes
│   └── src/app/docs/      Developer documentation portal
└── ml_sidecar/            Python ML service (SHAP explanations)
```

### Payment Flow

```
Client -> API -> Payment Saga -> Gateway Authorization
                      |
                      v
               Fraud Scoring (LightGBM + Rules)
                      |
              pass / review / block
                      |
                      v
               Double-Entry Ledger
                      |
                      v
               Webhook Delivery
```

### Key Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Event Sourcing | Rails Event Store | Complete audit trail, temporal queries, replay capability |
| Fraud ML | LightGBM + SHAP | Fast inference (<5ms), interpretable explanations, small model size |
| Ledger | Custom double-entry | Financial-grade accuracy, append-only, balanced invariant enforced at DB level |
| Monolith | Modular monolith | Domain isolation without network overhead; extract to services later if needed |
| Auth | Devise + JWT + MFA | Stateless API auth with TOTP-based MFA for sensitive operations |
| Encryption | Lockbox + Blind Index | Application-level PII encryption with searchable blind indexes |

## What Makes This Different

### 1. Real ML Fraud Scoring
Not mock data or hardcoded rules. A LightGBM model trained on 200K synthetic transactions (2% fraud rate, 5-fold cross-validated, AUC 1.0) with SHAP-based explanations for every decision. A rule engine provides deterministic guardrails (velocity checks, amount thresholds, time-of-day analysis).

### 2. Financial-Grade Ledger
Every payment creates balanced double-entry ledger records across 6 account types (settlement, processing, available, reserve, fees_collected, transaction_fees). Property-based tests verify the fundamental accounting equation (debits == credits) holds across thousands of random transaction sequences with random fee structures.

### 3. Enterprise Security Posture
- Brakeman: 0 warnings
- bundler-audit: 0 vulnerabilities
- Lockbox AES-256-GCM encryption for PII
- Blind indexes for encrypted field search
- Action Policy RBAC with 4 roles
- Rack::Attack rate limiting
- secure_headers CSP/HSTS
- PaperTrail audit trail on all models
- JWT revocation via denylist

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Ruby 3.4, Rails 8.1 (API mode) |
| Frontend | Next.js 15, React 19, TypeScript, Tailwind 4 |
| Database | PostgreSQL 16 (UUID primary keys) |
| Cache/Queue | Redis, Sidekiq 7 |
| Event Store | Rails Event Store 2.18 |
| Auth | Devise 5 + JWT + TOTP MFA |
| Authorization | Action Policy |
| Encryption | Lockbox + Blind Index |
| Fraud ML | LightGBM (Ruby), SHAP (Python sidecar) |
| Audit | PaperTrail + Event Sourcing |
| API Docs | Interactive developer portal (Next.js) |

## Testing

```bash
# Run all tests
cd backend && bundle exec rspec

# Run with coverage report
COVERAGE=true bundle exec rspec

# Run specific test suites
bundle exec rspec spec/mutation/          # Mutation-equivalent boundary tests
bundle exec rspec spec/property/          # Property-based invariant tests
bundle exec rspec spec/contracts/         # API contract tests
bundle exec rspec spec/integration/       # Full lifecycle integration tests
bundle exec rspec spec/security/          # Security & compliance tests

# Static analysis
bundle exec brakeman --no-pager
bundle exec bundle-audit check --update
```

### Test Coverage Summary

| Category | Tests | What It Proves |
|----------|-------|----------------|
| Unit | 200+ | Individual domain logic correctness |
| Integration | 30+ | Full payment lifecycle end-to-end |
| Property-based | 50+ | Ledger invariants hold across random inputs |
| Mutation-equivalent | 80+ | Tests catch operator flips, boundary changes, removed guards |
| Contract | 15+ | API response schemas match frontend expectations |
| Security | 20+ | Encryption, OWASP compliance, password policy |
| Request | 34 | All API endpoints authenticated and authorized |

## API

Base URL: `/api/v1`

| Endpoint | Description |
|----------|-------------|
| `POST /transactions` | Create payment |
| `GET /transactions` | List with filters |
| `GET /transactions/:id` | Payment detail |
| `POST /transactions/:id/capture` | Capture authorized payment |
| `POST /transactions/:id/refund` | Full or partial refund |
| `POST /transactions/:id/void` | Void authorization |
| `GET /transactions/:id/events` | Event stream |
| `GET /transactions/:id/ledger` | Ledger entries |
| `GET /fraud/cases` | Fraud case queue |
| `POST /fraud/cases/:id/review` | Review decision |
| `GET /merchants/me` | Merchant profile |
| `GET /merchants/me/balance` | Account balances |
| `POST /api_keys` | Create API key |
| `POST /webhooks/test` | Test webhook delivery |

See `/docs` in the frontend for interactive API documentation with code examples in cURL, JavaScript, Python, and Ruby.

## Project Structure

```
backend/
├── app/
│   ├── blueprints/        Blueprinter serializers
│   ├── controllers/api/v1/ Versioned API controllers
│   ├── domains/
│   │   ├── fraud/
│   │   │   ├── models/     FraudCase
│   │   │   ├── rules/      VelocityRule, AmountRule, etc.
│   │   │   └── services/   FraudScoringEngine, RuleEngine, FeatureExtractor
│   │   ├── ledger/
│   │   │   └── services/   DoubleEntryService
│   │   ├── payments/
│   │   │   ├── aggregates/ PaymentAggregate (event-sourced)
│   │   │   ├── events/     Domain events
│   │   │   ├── sagas/      PaymentLifecycleSaga
│   │   │   └── services/   GatewayClient
│   │   └── webhooks/
│   │       └── services/   WebhookDeliveryService
│   ├── models/             ActiveRecord models
│   └── policies/           Action Policy authorization
├── ml_models/              Trained LightGBM model
└── spec/
    ├── contracts/          API contract tests
    ├── domains/            Domain unit tests
    ├── integration/        End-to-end tests
    ├── mutation/           Mutation-equivalent tests
    ├── property/           Property-based tests
    ├── requests/           API request specs
    └── security/           Security tests
```

## License

This project is for demonstration and educational purposes.
