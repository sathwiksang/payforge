"use client";

import dynamic from "next/dynamic";
import { CodeBlock } from "@/components/docs/code-block";
import { Shield, Lock, Key, Eye, ShieldCheck, AlertTriangle } from "lucide-react";

const EncryptionFlow = dynamic(
  () => import("@/components/interactive/encryption-flow").then((m) => m.EncryptionFlow),
  { ssr: false }
);

export default function SecurityPage() {
  return (
    <article className="max-w-4xl">
      <div className="mb-10">
        <div className="inline-flex items-center gap-1.5 rounded-full border border-amber-200 bg-amber-50 px-3 py-1 text-[11px] font-medium text-amber-700 mb-4">
          <Shield size={11} />
          Platform
        </div>
        <h1 className="text-4xl font-bold text-slate-900 tracking-tight mb-3">Security</h1>
        <p className="text-lg text-slate-500 leading-relaxed">
          PayForge implements defense-in-depth security controls covering encryption, authentication,
          authorization, and audit logging — aligned with PCI DSS 4.0 requirements.
        </p>
      </div>

      {/* Security Summary */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-12">
        {[
          { value: "0", label: "Brakeman Warnings", color: "emerald" },
          { value: "0", label: "Audit Vulnerabilities", color: "emerald" },
          { value: "AES-256", label: "Encryption at Rest", color: "indigo" },
          { value: "JWT+MFA", label: "Authentication", color: "purple" },
        ].map((s) => (
          <div key={s.label} className="rounded-xl border border-slate-200 p-4 text-center">
            <div className={`text-xl font-bold ${s.color === "emerald" ? "text-emerald-600" : s.color === "indigo" ? "text-indigo-600" : "text-purple-600"}`}>
              {s.value}
            </div>
            <div className="text-[11px] text-slate-500 mt-1">{s.label}</div>
          </div>
        ))}
      </div>

      {/* Authentication */}
      <section className="mb-12">
        <div className="flex items-center gap-2.5 mb-4">
          <div className="rounded-lg bg-indigo-100 p-2">
            <Key size={16} className="text-indigo-600" />
          </div>
          <h2 className="text-2xl font-bold text-slate-900">Authentication</h2>
        </div>
        <p className="text-sm text-slate-600 mb-4 leading-relaxed">
          PayForge uses JWT-based authentication with short-lived tokens. All API requests require a Bearer token
          in the Authorization header.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {[
            {
              icon: Key,
              title: "JWT Tokens",
              desc: "Stateless tokens signed with RS256. Configurable expiration with automatic refresh. Revocation via server-side denylist.",
            },
            {
              icon: Lock,
              title: "API Keys",
              desc: "Long-lived keys for server-to-server integration. Hashed with bcrypt before storage — plaintext keys are never stored.",
            },
            {
              icon: ShieldCheck,
              title: "Multi-Factor Auth",
              desc: "TOTP-based MFA for dashboard access. Required for sensitive operations like API key management and user administration.",
            },
            {
              icon: Eye,
              title: "Session Management",
              desc: "JWT revocation via denylist on sign-out. Automatic token expiry. Account lockout after 5 failed login attempts.",
            },
          ].map((item) => (
            <div key={item.title} className="rounded-xl border border-slate-200 p-5 hover:border-slate-300 transition-colors">
              <div className="flex items-center gap-2 mb-2">
                <item.icon size={14} className="text-indigo-500" />
                <h3 className="text-sm font-semibold text-slate-900">{item.title}</h3>
              </div>
              <p className="text-xs text-slate-500 leading-relaxed">{item.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Encryption */}
      <section className="mb-12">
        <div className="flex items-center gap-2.5 mb-4">
          <div className="rounded-lg bg-emerald-100 p-2">
            <Lock size={16} className="text-emerald-600" />
          </div>
          <h2 className="text-2xl font-bold text-slate-900">Encryption</h2>
        </div>
        <p className="text-sm text-slate-600 mb-6 leading-relaxed">
          Sensitive data is encrypted at multiple layers using industry-standard algorithms.
          Watch the encryption pipeline in action:
        </p>

        <div className="mb-6">
          <EncryptionFlow />
        </div>

        <div className="rounded-xl border border-slate-200 overflow-hidden mb-4">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-slate-50 border-b border-slate-200">
                <th className="text-left px-4 py-3 font-semibold text-slate-900 text-xs uppercase tracking-wider">Layer</th>
                <th className="text-left px-4 py-3 font-semibold text-slate-900 text-xs uppercase tracking-wider">Method</th>
                <th className="text-left px-4 py-3 font-semibold text-slate-900 text-xs uppercase tracking-wider">Protects</th>
              </tr>
            </thead>
            <tbody>
              {[
                { layer: "Transport", method: "TLS 1.3", protects: "All API traffic in transit" },
                { layer: "Application", method: "Lockbox (AES-256-GCM)", protects: "PII fields: email, card data, webhook URLs" },
                { layer: "Search", method: "Blind Index (HMAC)", protects: "Searchable encrypted field lookups" },
                { layer: "Database", method: "PostgreSQL encryption", protects: "All data at rest on disk" },
                { layer: "Secrets", method: "Rails encrypted credentials", protects: "API keys, signing keys, master keys" },
              ].map((row, i) => (
                <tr key={row.layer} className={i % 2 === 1 ? "bg-slate-50/50" : ""}>
                  <td className="px-4 py-3 font-medium text-slate-900 text-sm">{row.layer}</td>
                  <td className="px-4 py-3 font-mono text-xs text-indigo-600">{row.method}</td>
                  <td className="px-4 py-3 text-slate-600 text-sm">{row.protects}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <CodeBlock
          language="ruby"
          title="Application-level encryption with Lockbox"
          code={`class Merchant < ApplicationRecord
  # PII encrypted with AES-256-GCM using Lockbox
  has_encrypted :email
  blind_index :email   # Enables searching encrypted fields

  # Webhook URL also encrypted (contains merchant secrets)
  has_encrypted :webhook_url
end

# Transparent usage — encryption/decryption is automatic
merchant = Merchant.find_by(email: "merchant@example.com")
# → Queries blind_index column, decrypts email on read`}
        />
      </section>

      {/* Authorization */}
      <section className="mb-12">
        <div className="flex items-center gap-2.5 mb-4">
          <div className="rounded-lg bg-purple-100 p-2">
            <ShieldCheck size={16} className="text-purple-600" />
          </div>
          <h2 className="text-2xl font-bold text-slate-900">Authorization</h2>
        </div>
        <p className="text-sm text-slate-600 mb-4 leading-relaxed">
          Role-based access control is enforced at every endpoint using <strong>Action Policy</strong>. All resources
          are automatically scoped to the authenticated merchant — there is no way to access another merchant&apos;s data.
        </p>
        <div className="rounded-xl border border-slate-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-slate-50 border-b border-slate-200">
                <th className="text-left px-4 py-3 font-semibold text-slate-900 text-xs uppercase tracking-wider">Role</th>
                <th className="text-left px-4 py-3 font-semibold text-slate-900 text-xs uppercase tracking-wider">Permissions</th>
              </tr>
            </thead>
            <tbody>
              {[
                { role: "Viewer", perms: "Read transactions, view analytics and dashboards" },
                { role: "Manager", perms: "All viewer + process payments, manage webhooks, review fraud cases" },
                { role: "Admin", perms: "All manager + manage API keys, users, merchant settings" },
                { role: "Super Admin", perms: "All admin + manage merchants, system configuration, full CRUD" },
              ].map((row, i) => (
                <tr key={row.role} className={i % 2 === 1 ? "bg-slate-50/50" : ""}>
                  <td className="px-4 py-3 font-semibold text-slate-900 text-sm">{row.role}</td>
                  <td className="px-4 py-3 text-slate-600 text-sm">{row.perms}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* Rate Limiting */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold text-slate-900 mb-4">Rate Limiting</h2>
        <p className="text-sm text-slate-600 mb-4 leading-relaxed">
          API requests are rate-limited using <strong>Rack::Attack</strong> with a sliding window counter
          to prevent abuse and ensure fair usage:
        </p>
        <div className="grid grid-cols-3 gap-3 mb-4">
          {[
            { label: "Standard API", value: "100 req/min", desc: "Per API key" },
            { label: "Authentication", value: "5 req/min", desc: "Per IP address" },
            { label: "Webhooks Test", value: "10 req/min", desc: "Test endpoint" },
          ].map((item) => (
            <div key={item.label} className="rounded-xl border border-slate-200 p-4 text-center hover:border-slate-300 transition-colors">
              <div className="text-[11px] text-slate-400 mb-1">{item.label}</div>
              <div className="text-base font-bold text-slate-900">{item.value}</div>
              <div className="text-[11px] text-slate-500 mt-0.5">{item.desc}</div>
            </div>
          ))}
        </div>
        <CodeBlock
          language="http"
          title="Rate limit response headers"
          code={`X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1709726400`}
        />
      </section>

      {/* Security Headers */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold text-slate-900 mb-4">Security Headers</h2>
        <p className="text-sm text-slate-600 mb-4">
          All responses include security headers configured via <code className="text-xs bg-slate-100 px-1.5 py-0.5 rounded font-mono text-indigo-600">secure_headers</code>:
        </p>
        <CodeBlock
          language="http"
          title="Response security headers"
          code={`Content-Security-Policy: default-src 'none'; frame-ancestors 'none'
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 0
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), camera=(), microphone=()`}
        />
      </section>

      {/* Audit Trail */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold text-slate-900 mb-4">Audit Trail</h2>
        <p className="text-sm text-slate-600 mb-4 leading-relaxed">
          Every mutation is tracked with <strong>PaperTrail</strong> versioning and domain events.
          The audit trail captures:
        </p>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {[
            { label: "Who", desc: "Authenticated user ID", icon: "user" },
            { label: "What", desc: "Action + changed data", icon: "edit" },
            { label: "When", desc: "Microsecond timestamp", icon: "clock" },
            { label: "Where", desc: "IP address + endpoint", icon: "map" },
          ].map((item) => (
            <div key={item.label} className="rounded-xl border border-slate-200 p-4 text-center">
              <div className="text-sm font-bold text-slate-900 mb-1">{item.label}</div>
              <div className="text-xs text-slate-500">{item.desc}</div>
            </div>
          ))}
        </div>
      </section>

      {/* Best Practices */}
      <section className="mb-10">
        <h2 className="text-2xl font-bold text-slate-900 mb-4">Integration Best Practices</h2>
        <div className="space-y-3">
          {[
            {
              icon: Key,
              title: "Use test keys in development",
              desc: "Test keys (sk_test_...) work identically to live keys but don't process real payments. Never use production keys in development.",
            },
            {
              icon: ShieldCheck,
              title: "Verify webhook signatures",
              desc: "Always verify the X-PayForge-Signature header before processing webhook events. See the Webhooks documentation for implementation examples.",
            },
            {
              icon: Lock,
              title: "Use idempotency keys",
              desc: "Include X-Idempotency-Key on all POST requests to prevent duplicate processing during retries or network issues.",
            },
            {
              icon: AlertTriangle,
              title: "Store keys securely",
              desc: "Use environment variables or a secrets manager. Never commit API keys to source control. Rotate keys regularly.",
            },
            {
              icon: Shield,
              title: "Implement exponential backoff",
              desc: "When rate-limited (429), back off exponentially. Start with 1 second and double on each retry, up to a maximum of 30 seconds.",
            },
          ].map((item) => (
            <div key={item.title} className="flex gap-3.5 rounded-xl border border-slate-200 p-4 hover:border-slate-300 transition-colors">
              <div className="rounded-lg bg-slate-100 p-2 h-fit">
                <item.icon size={14} className="text-slate-500" />
              </div>
              <div>
                <h3 className="text-sm font-semibold text-slate-900 mb-0.5">{item.title}</h3>
                <p className="text-xs text-slate-500 leading-relaxed">{item.desc}</p>
              </div>
            </div>
          ))}
        </div>
      </section>
    </article>
  );
}
