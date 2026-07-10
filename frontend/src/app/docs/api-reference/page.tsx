"use client";

import { useState } from "react";
import { ApiExplorer } from "@/components/docs/api-explorer";
import { ApiPlayground } from "@/components/docs/api-playground";
import { Code2, Zap, Terminal } from "lucide-react";

const SECTIONS = [
  { id: "playground", label: "API Playground" },
  { id: "transactions", label: "Transactions" },
  { id: "merchants", label: "Merchants" },
  { id: "fraud", label: "Fraud Intelligence" },
  { id: "webhooks-api", label: "Webhooks" },
  { id: "api-keys", label: "API Keys" },
];

export default function ApiReferencePage() {
  const [activeSection, setActiveSection] = useState<string | null>(null);

  return (
    <article className="max-w-3xl">
      <div className="mb-10">
        <div className="inline-flex items-center gap-1.5 rounded-full border border-blue-200 bg-blue-50 px-3 py-1 text-[11px] font-medium text-blue-700 mb-4">
          <Code2 size={11} />
          API
        </div>
        <h1 className="text-4xl font-bold text-slate-900 tracking-tight mb-3">API Reference</h1>
        <p className="text-lg text-slate-500 leading-relaxed">
          Complete reference for the PayForge REST API. All endpoints require authentication via Bearer token.
        </p>
        <div className="mt-3 flex items-center gap-2">
          <span className="text-xs text-slate-400">Base URL:</span>
          <code className="text-xs bg-slate-100 px-2.5 py-1 rounded-md font-mono text-indigo-600 font-medium">
            https://api.payforge.dev/api/v1
          </code>
        </div>
      </div>

      {/* On-page nav */}
      <div className="flex flex-wrap gap-2 mb-10 pb-6 border-b border-slate-200">
        {SECTIONS.map((s) => (
          <a
            key={s.id}
            href={`#${s.id}`}
            className="rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-medium text-slate-600 hover:border-indigo-200 hover:text-indigo-600 hover:bg-indigo-50 transition-all"
          >
            {s.label}
          </a>
        ))}
      </div>

      {/* Live API Playground */}
      <section id="playground" className="mb-14">
        <div className="flex items-center gap-2.5 mb-4">
          <div className="rounded-lg bg-indigo-100 p-2">
            <Terminal size={16} className="text-indigo-600" />
          </div>
          <h2 className="text-2xl font-bold text-slate-900">API Playground</h2>
        </div>
        <p className="text-sm text-slate-600 mb-4">
          Make real API calls against the live backend directly from the docs. Click <strong>Quick Login</strong> to
          authenticate with the demo account, then send requests to see actual responses.
        </p>

        <ApiPlayground
          method="GET"
          path="/api/v1/transactions"
          description="Fetch your recent transactions. Try it now!"
          defaultParams={{}}
        />

        <ApiPlayground
          method="POST"
          path="/api/v1/transactions"
          description="Create a new payment transaction."
          defaultBody={`{
  "transaction": {
    "amount_cents": 2500,
    "currency": "USD",
    "card_last_four": "4242",
    "card_brand": "visa",
    "card_token": "tok_visa_4242",
    "idempotency_key": "idem_${Date.now()}"
  }
}`}
        />

        <ApiPlayground
          method="GET"
          path="/api/v1/merchants/me/analytics"
          description="Get your merchant analytics including volume, revenue, and fraud rate."
        />

        <ApiPlayground
          method="GET"
          path="/api/v1/fraud/stats"
          description="Get aggregate fraud statistics."
        />
      </section>

      {/* Transactions */}
      <section id="transactions" className="mb-14">
        <div className="flex items-center gap-2.5 mb-2">
          <div className="rounded-lg bg-emerald-100 p-2">
            <Zap size={16} className="text-emerald-600" />
          </div>
          <h2 className="text-2xl font-bold text-slate-900">Transactions</h2>
        </div>
        <p className="text-sm text-slate-600 mb-4">
          Create, capture, refund, and void payments. All POST endpoints support idempotency via the{" "}
          <code className="text-xs bg-slate-100 px-1.5 py-0.5 rounded font-mono">X-Idempotency-Key</code> header.
        </p>

        <ApiExplorer
          method="POST"
          path="/api/v1/transactions"
          description="Create a new transaction. The payment will be authorized, fraud-scored, and captured automatically by the Saga orchestrator."
          requestBody={`{
  "transaction": {
    "amount_cents": 5000,
    "currency": "USD",
    "card_last_four": "4242",
    "card_brand": "visa",
    "card_token": "tok_visa_4242",
    "idempotency_key": "idem_abc123",
    "metadata": { "order_id": "ord_123" }
  }
}`}
          sampleResponse={`{
  "data": {
    "id": "a1b2c3d4-e5f6-...",
    "merchant_id": "m1n2o3p4-...",
    "status": "captured",
    "amount": { "cents": 5000, "currency": "USD", "formatted": "$50.00" },
    "fee_cents": 175,
    "net_cents": 4825,
    "card_last_four": "4242",
    "card_brand": "visa",
    "fraud_score": "0.0312",
    "fraud_decision": "pass",
    "idempotency_key": "idem_abc123",
    "created_at": "2026-03-06T10:30:00Z"
  },
  "meta": { "request_id": "req_01DEF...", "processing_time_ms": 42 }
}`}
        />

        <ApiExplorer
          method="GET"
          path="/api/v1/transactions"
          description="List transactions with filtering and pagination."
          parameters={[
            { name: "page", type: "integer", description: "Page number", default: "1" },
            { name: "per_page", type: "integer", description: "Results per page (max 100)", default: "25" },
            { name: "status", type: "string", description: "Filter: captured, authorized, refunded, voided, blocked, failed, settled" },
            { name: "from", type: "string", description: "Start date (ISO 8601)" },
            { name: "to", type: "string", description: "End date (ISO 8601)" },
            { name: "min_amount", type: "integer", description: "Minimum amount in cents" },
            { name: "max_amount", type: "integer", description: "Maximum amount in cents" },
          ]}
          sampleResponse={`{
  "data": [
    {
      "id": "a1b2c3d4-...",
      "status": "captured",
      "amount": { "cents": 5000, "currency": "USD", "formatted": "$50.00" },
      "fraud_score": "0.0312",
      "card_brand": "visa",
      "created_at": "2026-03-06T10:30:00Z"
    }
  ],
  "meta": { "total_count": 5678, "page": 1, "per_page": 25, "total_pages": 228 },
  "links": { "self": "/api/v1/transactions?page=1", "next": "/api/v1/transactions?page=2" }
}`}
        />

        <ApiExplorer
          method="GET"
          path="/api/v1/transactions/:id"
          description="Get full details of a specific transaction."
          sampleResponse={`{
  "data": {
    "id": "a1b2c3d4-...",
    "status": "captured",
    "amount": { "cents": 5000, "currency": "USD", "formatted": "$50.00" },
    "fee_cents": 175,
    "net_cents": 4825,
    "fraud_score": "0.0312",
    "fraud_decision": "pass",
    "card_last_four": "4242",
    "card_brand": "visa",
    "idempotency_key": "idem_abc123",
    "created_at": "2026-03-06T10:30:00Z"
  },
  "meta": { "request_id": "req_01GHI..." }
}`}
        />

        <ApiExplorer
          method="POST"
          path="/api/v1/transactions/:id/capture"
          description="Capture an authorized payment. Optionally specify a partial capture amount."
          requestBody={`{ "amount_cents": 5000 }`}
          sampleResponse={`{
  "data": { "id": "a1b2c3d4-...", "status": "captured", "amount": { "cents": 5000, "formatted": "$50.00" } },
  "meta": { "request_id": "req_01JKL..." }
}`}
        />

        <ApiExplorer
          method="POST"
          path="/api/v1/transactions/:id/refund"
          description="Refund a captured payment. Supports full and partial refunds."
          requestBody={`{ "amount_cents": 2500 }`}
          sampleResponse={`{
  "data": { "id": "a1b2c3d4-...", "status": "partially_refunded", "amount": { "cents": 5000 } },
  "meta": { "request_id": "req_01MNO..." }
}`}
        />

        <ApiExplorer
          method="POST"
          path="/api/v1/transactions/:id/void"
          description="Void an authorized payment before capture."
          sampleResponse={`{
  "data": { "id": "a1b2c3d4-...", "status": "voided" },
  "meta": { "request_id": "req_01PQR..." }
}`}
        />

        <ApiExplorer
          method="GET"
          path="/api/v1/transactions/:id/events"
          description="Get the immutable event stream for a transaction. Shows every state change with timestamps."
          sampleResponse={`{
  "data": [
    { "type": "Payments::Events::PaymentInitiated", "data": { "amount_cents": 5000 }, "timestamp": "2026-03-06T10:30:00Z" },
    { "type": "Payments::Events::PaymentAuthorized", "data": { "auth_code": "A12345" }, "timestamp": "2026-03-06T10:30:01Z" },
    { "type": "Payments::Events::FraudCheckPassed", "data": { "score": 0.03 }, "timestamp": "2026-03-06T10:30:02Z" },
    { "type": "Payments::Events::PaymentCaptured", "data": {}, "timestamp": "2026-03-06T10:31:00Z" }
  ]
}`}
        />

        <ApiExplorer
          method="GET"
          path="/api/v1/transactions/:id/ledger"
          description="Get double-entry ledger entries for a transaction."
          sampleResponse={`{
  "data": [
    { "id": "...", "debit_account": "acc_merchant", "credit_account": "acc_processing", "amount_cents": 5000, "entry_type": "capture", "created_at": "2026-03-06T10:31:00Z" },
    { "id": "...", "debit_account": "acc_fees", "credit_account": "acc_merchant", "amount_cents": 175, "entry_type": "fee", "created_at": "2026-03-06T10:31:00Z" }
  ]
}`}
        />
      </section>

      {/* Merchants */}
      <section id="merchants" className="mb-14">
        <h2 className="text-2xl font-bold text-slate-900 mb-2">Merchants</h2>
        <p className="text-sm text-slate-600 mb-4">
          Manage your merchant profile, view analytics, and check balances.
        </p>

        <ApiExplorer
          method="GET"
          path="/api/v1/merchants/me"
          description="Get your merchant profile and configuration."
          sampleResponse={`{
  "data": {
    "id": "m1n2o3p4-...",
    "name": "Demo Merchant",
    "status": "active",
    "fee_percentage": "2.9",
    "fee_fixed_cents": 30,
    "risk_tier": "standard",
    "transaction_count": 5234,
    "created_at": "2026-01-15T08:00:00Z"
  }
}`}
        />

        <ApiExplorer
          method="GET"
          path="/api/v1/merchants/me/analytics"
          description="Get aggregate analytics for your merchant."
          sampleResponse={`{
  "data": {
    "analytics": {
      "total_volume_cents": 28452000,
      "total_revenue_cents": 824908,
      "transaction_count": 5234,
      "fraud_rate": 0.024,
      "avg_transaction_cents": 5435
    }
  }
}`}
        />

        <ApiExplorer
          method="GET"
          path="/api/v1/merchants/me/balance"
          description="Get current account balances by type."
          sampleResponse={`{
  "data": [
    { "id": "acc_01...", "account_type": "merchant", "currency": "USD", "balance_cents": 284520 },
    { "id": "acc_02...", "account_type": "fees_collected", "currency": "USD", "balance_cents": 8249 }
  ]
}`}
        />

        <ApiExplorer
          method="PATCH"
          path="/api/v1/merchants/me"
          description="Update your merchant settings."
          requestBody={`{
  "name": "Updated Merchant Name",
  "webhook_url": "https://example.com/webhooks"
}`}
          sampleResponse={`{
  "data": {
    "id": "m1n2o3p4-...",
    "name": "Updated Merchant Name",
    "webhook_url": "configured"
  }
}`}
        />
      </section>

      {/* Fraud */}
      <section id="fraud" className="mb-14">
        <h2 className="text-2xl font-bold text-slate-900 mb-2">Fraud Intelligence</h2>
        <p className="text-sm text-slate-600 mb-4">
          Review fraud cases, view ML-powered risk scores with SHAP explanations, and manage decisions.
        </p>

        <ApiExplorer
          method="GET"
          path="/api/v1/fraud/cases"
          description="List fraud cases for your merchant with filtering by status and priority."
          parameters={[
            { name: "status", type: "string", description: "Filter: open, confirmed_fraud, false_positive" },
            { name: "priority", type: "string", description: "Filter: low, medium, high, critical" },
            { name: "page", type: "integer", description: "Page number", default: "1" },
          ]}
          sampleResponse={`{
  "data": [
    {
      "id": "fc_01...",
      "risk_score": "0.8700",
      "status": "open",
      "priority": 2,
      "decision": "review",
      "model_used": "lgbm_v1",
      "created_at": "2026-03-06T10:30:00Z"
    }
  ],
  "meta": { "total_count": 12, "page": 1, "per_page": 25 }
}`}
        />

        <ApiExplorer
          method="POST"
          path="/api/v1/fraud/cases/:id/review"
          description="Submit a review decision for a fraud case."
          requestBody={`{
  "status": "false_positive",
  "notes": "Verified with customer via phone"
}`}
          sampleResponse={`{
  "data": {
    "id": "fc_01...",
    "status": "false_positive",
    "reviewed_at": "2026-03-06T11:00:00Z",
    "notes": "Verified with customer via phone"
  }
}`}
        />

        <ApiExplorer
          method="GET"
          path="/api/v1/fraud/stats"
          description="Get aggregate fraud statistics for your merchant."
          sampleResponse={`{
  "data": {
    "total_cases": 156,
    "open_cases": 12,
    "fraud_rate": 0.024,
    "avg_risk_score": 0.34,
    "by_priority": { "critical": 2, "high": 10, "medium": 45, "low": 99 }
  }
}`}
        />
      </section>

      {/* Webhooks */}
      <section id="webhooks-api" className="mb-14">
        <h2 className="text-2xl font-bold text-slate-900 mb-2">Webhooks</h2>
        <p className="text-sm text-slate-600 mb-4">
          View webhook delivery history and test your endpoint.
        </p>

        <ApiExplorer
          method="GET"
          path="/api/v1/webhooks/deliveries"
          description="List recent webhook delivery attempts."
          sampleResponse={`{
  "data": [
    {
      "id": "wd_01...",
      "event_type": "payment.captured",
      "status": "delivered",
      "response_code": 200,
      "attempts": 1,
      "delivered_at": "2026-03-06T10:31:02Z"
    }
  ]
}`}
        />

        <ApiExplorer
          method="GET"
          path="/api/v1/webhooks/status"
          description="Get webhook endpoint status and delivery success rate."
          sampleResponse={`{
  "data": {
    "webhook_configured": true,
    "recent_deliveries": 42,
    "success_rate": 0.98
  }
}`}
        />

        <ApiExplorer
          method="POST"
          path="/api/v1/webhooks/test"
          description="Send a test webhook event to your configured endpoint."
          requestBody={`{ "event_type": "payment.captured" }`}
          sampleResponse={`{
  "data": { "message": "Test webhook sent", "delivery_id": "wd_test_01..." }
}`}
        />
      </section>

      {/* API Keys */}
      <section id="api-keys" className="mb-14">
        <h2 className="text-2xl font-bold text-slate-900 mb-2">API Keys</h2>
        <p className="text-sm text-slate-600 mb-4">
          Manage API keys for programmatic authentication.
        </p>

        <ApiExplorer
          method="GET"
          path="/api/v1/api_keys"
          description="List all API keys for your merchant."
          sampleResponse={`{
  "data": [
    { "id": "key_01...", "name": "Production", "prefix": "sk_live_abc1", "last_used_at": "2026-03-06T10:00:00Z", "created_at": "2026-01-01T00:00:00Z" }
  ]
}`}
        />

        <ApiExplorer
          method="POST"
          path="/api/v1/api_keys"
          description="Create a new API key. The full key value is only returned once at creation."
          requestBody={`{ "name": "Production Key" }`}
          sampleResponse={`{
  "data": {
    "id": "key_01...",
    "name": "Production Key",
    "key": "sk_live_abc123def456...",
    "prefix": "sk_live_abc1",
    "created_at": "2026-03-06T10:00:00Z"
  }
}`}
        />

        <ApiExplorer
          method="POST"
          path="/api/v1/api_keys/:id/rotate"
          description="Rotate an API key. Generates a new key and revokes the old one."
          sampleResponse={`{
  "data": {
    "id": "key_02...",
    "name": "Production Key",
    "key": "sk_live_xyz789...",
    "prefix": "sk_live_xyz7"
  }
}`}
        />
      </section>
    </article>
  );
}
