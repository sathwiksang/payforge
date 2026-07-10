"use client";

import { CodeBlock } from "@/components/docs/code-block";

const ERROR_CATEGORIES = [
  {
    category: "Authentication Errors",
    errors: [
      { code: "authentication_required", status: 401, message: "No valid API key provided", resolution: "Include a valid Bearer token in the Authorization header." },
      { code: "invalid_api_key", status: 401, message: "The API key provided is invalid or revoked", resolution: "Check your key in the dashboard. Revoked keys cannot be reused." },
      { code: "mfa_required", status: 403, message: "MFA verification required for this action", resolution: "Complete MFA verification before retrying." },
    ],
  },
  {
    category: "Authorization Errors",
    errors: [
      { code: "forbidden", status: 403, message: "You do not have permission to perform this action", resolution: "Check your user role. Admin or manager access may be required." },
      { code: "no_merchant", status: 403, message: "No merchant account associated with this user", resolution: "Ensure your user is linked to a merchant account." },
    ],
  },
  {
    category: "Validation Errors",
    errors: [
      { code: "validation_error", status: 422, message: "One or more parameters are invalid", resolution: "Check the error details for the specific field and constraint." },
      { code: "amount_below_minimum", status: 422, message: "Payment amount must be at least 50 cents", resolution: "Ensure amount_cents >= 50." },
      { code: "invalid_currency", status: 422, message: "The specified currency is not supported", resolution: "Use a supported currency: USD, EUR, GBP, CAD, AUD." },
      { code: "invalid_card_token", status: 422, message: "The card token is invalid or expired", resolution: "Generate a new card token and retry." },
    ],
  },
  {
    category: "Payment Errors",
    errors: [
      { code: "payment_declined", status: 422, message: "The payment was declined by the network", resolution: "The cardholder should contact their issuing bank." },
      { code: "fraud_blocked", status: 422, message: "Payment blocked by fraud detection", resolution: "Review the fraud case in the dashboard. Contact support if this is a false positive." },
      { code: "already_captured", status: 422, message: "This payment has already been captured", resolution: "A payment can only be captured once." },
      { code: "already_voided", status: 422, message: "This payment has already been voided", resolution: "Voided payments cannot be modified." },
      { code: "capture_expired", status: 422, message: "Authorization has expired and can no longer be captured", resolution: "Create a new payment. Authorizations expire after 7 days." },
    ],
  },
  {
    category: "Rate Limiting",
    errors: [
      { code: "rate_limit_exceeded", status: 429, message: "Too many requests", resolution: "Back off and retry with exponential backoff. Default limit: 100 req/min." },
    ],
  },
  {
    category: "Resource Errors",
    errors: [
      { code: "not_found", status: 404, message: "The requested resource does not exist", resolution: "Verify the resource ID. Resources are scoped to your merchant." },
      { code: "idempotency_conflict", status: 409, message: "A different request was already made with this idempotency key", resolution: "Use a unique X-Idempotency-Key for each distinct request." },
    ],
  },
  {
    category: "Server Errors",
    errors: [
      { code: "internal_error", status: 500, message: "An unexpected error occurred", resolution: "Retry the request. If the issue persists, contact support with the request_id." },
      { code: "service_unavailable", status: 503, message: "The service is temporarily unavailable", resolution: "Retry with exponential backoff. Check status.payforge.dev for incidents." },
    ],
  },
];

export default function ErrorCodesPage() {
  return (
    <article className="max-w-3xl">
      <h1 className="text-3xl font-bold text-[var(--pf-text-primary)] mb-2">Error Codes</h1>
      <p className="text-lg text-[var(--pf-text-secondary)] mb-8">
        Complete reference of error codes returned by the PayForge API with resolution guidance.
      </p>

      {/* Error format */}
      <section className="mb-10">
        <h2 className="text-xl font-semibold text-[var(--pf-text-primary)] mb-3">Error Response Format</h2>
        <p className="text-sm text-[var(--pf-text-secondary)] mb-3">
          All errors follow a consistent JSON structure with a type, machine-readable code, human-readable message,
          and a link to documentation.
        </p>
        <CodeBlock
          language="json"
          title="Error response"
          code={`{
  "error": {
    "type": "validation_error",
    "code": "amount_below_minimum",
    "message": "Payment amount must be at least 50 cents",
    "param": "amount_cents",
    "doc_url": "https://docs.payforge.dev/errors#amount_below_minimum"
  },
  "meta": {
    "request_id": "req_01GHI..."
  }
}`}
        />
      </section>

      {/* HTTP Status Codes */}
      <section className="mb-10">
        <h2 className="text-xl font-semibold text-[var(--pf-text-primary)] mb-3">HTTP Status Codes</h2>
        <div className="rounded-lg border border-[var(--pf-border)] overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-[var(--pf-bg-secondary)]">
                <th className="text-left px-4 py-2.5 font-semibold text-[var(--pf-text-primary)]">Code</th>
                <th className="text-left px-4 py-2.5 font-semibold text-[var(--pf-text-primary)]">Meaning</th>
              </tr>
            </thead>
            <tbody>
              {[
                { code: "200", meaning: "Success" },
                { code: "201", meaning: "Created" },
                { code: "401", meaning: "Unauthorized — invalid or missing API key" },
                { code: "403", meaning: "Forbidden — insufficient permissions" },
                { code: "404", meaning: "Not Found — resource doesn't exist" },
                { code: "409", meaning: "Conflict — idempotency key reuse" },
                { code: "422", meaning: "Unprocessable Entity — validation failed" },
                { code: "429", meaning: "Too Many Requests — rate limit exceeded" },
                { code: "500", meaning: "Internal Server Error" },
                { code: "503", meaning: "Service Unavailable" },
              ].map((row, i) => (
                <tr key={row.code} className={i % 2 === 0 ? "" : "bg-[var(--pf-bg-secondary)]/50"}>
                  <td className="px-4 py-2 font-mono text-xs font-semibold text-[var(--pf-text-primary)]">{row.code}</td>
                  <td className="px-4 py-2 text-[var(--pf-text-secondary)]">{row.meaning}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* Error catalog */}
      {ERROR_CATEGORIES.map((cat) => (
        <section key={cat.category} className="mb-10" id={cat.category.toLowerCase().replace(/\s/g, "-")}>
          <h2 className="text-xl font-semibold text-[var(--pf-text-primary)] mb-3">{cat.category}</h2>
          <div className="space-y-3">
            {cat.errors.map((err) => (
              <div
                key={err.code}
                id={err.code}
                className="rounded-lg border border-[var(--pf-border)] p-4 bg-[var(--pf-bg-secondary)]"
              >
                <div className="flex items-center gap-3 mb-2">
                  <code className="text-xs font-mono font-bold text-[var(--pf-text-primary)]">{err.code}</code>
                  <span className="text-xs px-2 py-0.5 rounded-full bg-red-100 text-red-700 font-medium">
                    {err.status}
                  </span>
                </div>
                <p className="text-sm text-[var(--pf-text-secondary)] mb-2">{err.message}</p>
                <p className="text-xs text-[var(--pf-text-tertiary)]">
                  <strong className="text-[var(--pf-text-secondary)]">Resolution:</strong> {err.resolution}
                </p>
              </div>
            ))}
          </div>
        </section>
      ))}
    </article>
  );
}
