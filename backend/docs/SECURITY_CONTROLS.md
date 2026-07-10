# PayForge Security Controls — PCI DSS 4.0 Mapping

## Encryption at Rest

| Control | Implementation | PCI DSS Req |
|---------|---------------|-------------|
| Merchant PII encryption | Lockbox AES-256-GCM (email, webhook URL, webhook secret) | 3.5 |
| Blind index for encrypted lookups | `blind_index :email` on Merchant | 3.5 |
| API key hashing | BCrypt with cost factor 12 | 8.6 |
| Master key management | `Rails.application.credentials.lockbox_master_key` | 3.6 |

## Authentication

| Control | Implementation | PCI DSS Req |
|---------|---------------|-------------|
| Password minimum length | 12 characters (Devise `password_length: 12..128`) | 8.2.3 |
| Account lockout | 5 failed attempts, 30-minute lockout (Devise `:lockable`) | 8.3.4 |
| Session timeout | 15 minutes (Devise `:timeoutable`) | 8.2.8 |
| Password hashing | bcrypt cost factor 12 (`Devise.stretches = 12`) | 8.3.2 |
| MFA | TOTP via `devise-two-factor` | 8.4 |
| JWT tokens | 1-hour expiry, denylist revocation | 8.6 |

## Authorization (Action Policy)

| Policy | Rules | PCI DSS Req |
|--------|-------|-------------|
| `TransactionPolicy` | RBAC (admin/manager/viewer) + ABAC (90-day refund window, merchant scoping) | 7.1, 7.2 |
| `MerchantPolicy` | Admin-only create, owner/admin update | 7.1 |
| `FraudCasePolicy` | Admin + analyst review; admin-only escalation | 7.1 |
| `verify_authorized` | Enforced on all API v1 controller actions | 7.2 |
| Relation scoping | Non-admins only see own merchant's data | 7.2 |

## Rate Limiting (Rack::Attack)

| Rule | Limit | PCI DSS Req |
|------|-------|-------------|
| General API | 100 requests/minute per IP | 6.4 |
| Login (by IP) | 5 requests/20 seconds | 8.3.4 |
| Login (by email) | 5 requests/minute | 8.3.4 |
| API key requests | 120 requests/minute per key | 6.4 |
| Payment creation | 20 requests/minute per API key | 6.4 |
| SQL injection probe | Blocklist on UNION/SELECT/DROP patterns | 6.5 |
| Missing User-Agent | Blocklist | 6.4 |

## Secure Headers

| Header | Value | PCI DSS Req |
|--------|-------|-------------|
| X-Frame-Options | DENY | 6.4 |
| X-Content-Type-Options | nosniff | 6.4 |
| HSTS | max-age=631138519; includeSubDomains; preload | 4.1 |
| CSP | default-src 'none'; script-src 'self'; frame-ancestors 'none' | 6.4 |
| Referrer-Policy | strict-origin-when-cross-origin | 6.4 |

## Audit Logging (PaperTrail)

| Feature | Implementation | PCI DSS Req |
|---------|---------------|-------------|
| Auditable concern | `app/models/concerns/auditable.rb` | 10.2 |
| Tracked models | Transaction, Merchant, User, ApiKey, FraudCase | 10.2 |
| Metadata | actor_id, actor_ip, action_type, merchant_id | 10.3 |
| Events tracked | create, update, destroy | 10.2 |

## API Key Management

| Feature | Implementation | PCI DSS Req |
|---------|---------------|-------------|
| Key generation | `pk_{env}_{SecureRandom.hex(24)}` | 8.6 |
| Storage | BCrypt hash (key_digest), prefix for lookup | 8.6 |
| Revocation | `revoke!` sets `revoked_at` | 8.6 |
| Expiry | `expires_at` field, checked in `.active` scope | 8.6 |
| Environment separation | test/live environments | 8.6 |

## Inter-Service Authentication

| Feature | Implementation | PCI DSS Req |
|---------|---------------|-------------|
| Service key | X-Service-Key header on `/internal/` paths | 7.2 |
| Timing-safe comparison | `ActiveSupport::SecurityUtils.secure_compare` | 8.6 |
| Middleware | `ServiceAuthentication` rack middleware | 7.2 |

## Automated Security Scanning

| Tool | Purpose | PCI DSS Req |
|------|---------|-------------|
| Brakeman | Static analysis (40+ vulnerability types) | 11.3 |
| bundler-audit | Dependency CVE scanning | 6.3 |
| RSpec security suite | OWASP Top 10 compliance verification | 11.3 |
