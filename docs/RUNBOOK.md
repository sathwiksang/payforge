# Runbook

## URLs & health

| What | URL |
|---|---|
| Frontend | https://payforge.sathwiksangeethamproject.dev |
| API health | https://payforge-api.sathwiksangeethamproject.dev/health |
| API docs page | https://payforge.sathwiksangeethamproject.dev/docs |

Demo login: `admin@payforge.dev` / `PayForge2026Secure` (production seed;
rotate via Rails console for public demos). Seeded data: 3 merchants,
~4,500 transactions with realistic fraud distribution.

## Deploy

Push to `main`. Pipeline: backend RSpec+zeitwerk+RuboCop (Postgres+Redis
services) and frontend lint+build → security scans → arm64 images → ECR →
SSM roll → public verify. Manual: Actions → deploy → Run workflow.

Host access is SSM-only (no SSH):

```bash
aws ssm start-session --target i-0f862e6a8a78d505a
```

## Common operations (on the host, `cd /opt/portfolio`)

```bash
docker logs -f portfolio-payforge-api              # API logs
docker logs -f portfolio-payforge-sidekiq          # worker logs
docker compose exec payforge-backend bin/rails c   # console
docker compose restart payforge-backend payforge-sidekiq
```

## Databases & seeds

`payforge_production`, role `payforge`, shared Postgres container.
Migrations run on deploy (entrypoint `db:prepare`). `db:seed` is **not
idempotent** for the transaction generator (idempotency-key collisions on
re-run) — safe to ignore on partial reruns; users/merchants use find_or_create.

## Failure playbook

| Symptom | First moves |
|---|---|
| API 502 | container down — `docker compose ps`, then logs; boot failures are usually eager-load or missing-env (see CI zeitwerk step) |
| Frontend loads, data empty | Browser calls the API directly — check CORS_ORIGINS on the backend and the baked NEXT_PUBLIC_API_URL in the frontend bundle |
| Jobs not processing | `docker logs portfolio-payforge-sidekiq`; Redis health (`docker compose ps redis`) |
| Fraud scores missing | ONNX sidecar path — check API logs for inference errors |
