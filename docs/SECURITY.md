# Security posture

## Boundaries

- Host exposes only Caddy's 80/443; SSM-only administration (no SSH keys).
- TLS at Caddy (Let's Encrypt). API CORS allowlist admits only the frontend origin.
- Client-side tokenization keeps raw card data out of the backend
  (see [ADR 005](adr/005-client-side-tokenization-pci.md)).

## Application

- JWT auth on the API; admin/merchant role separation.
- Event-sourced transactions + double-entry ledger give a tamper-evident,
  auditable money trail ([ADR 001](adr/001-event-sourcing-for-transactions.md),
  [ADR 008](adr/008-double-entry-accounting-design.md)).
- Encrypted Rails credentials; `RAILS_MASTER_KEY` from SSM-backed host env.
- Dedicated Postgres role `payforge`; blind_index/argon2 for searchable encryption.

## Pipeline

- Brakeman + bundler-audit + `npm audit` on every push (`security` job) —
  **informational** until findings are triaged, then blocking.
- RSpec (incl. property-based ledger tests) + zeitwerk gate every deploy.
- Dependabot weekly (bundler/backend, npm/frontend, actions).
- OIDC deploys via `portfolio-github-deploy` (scoped ECR + SSM; deletes denied).

## Known gaps (uplift backlog)

1. Triage security-scan findings → make the job blocking.
2. Rotate the seeded demo admin password for public demos.
3. Rate limiting on auth + payment intents (rack-attack).
4. Webhook signing-secret rotation story.
5. ESLint purity errors in the frontend (lint step informational).
