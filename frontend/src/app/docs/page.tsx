"use client";

import Link from "next/link";
import { CodeBlock, TabbedCodeBlock } from "@/components/docs/code-block";
import {
  ArrowRight,
  Code2,
  Webhook,
  AlertTriangle,
  Layers,
  Shield,
  CreditCard,
  BookOpen,
  Brain,
  Lock,
} from "lucide-react";

export default function GettingStartedPage() {
  return (
    <article className="max-w-3xl">
      {/* Page header */}
      <div className="mb-10">
        <div className="inline-flex items-center gap-1.5 rounded-full border border-indigo-200 bg-indigo-50 px-3 py-1 text-[11px] font-medium text-indigo-700 mb-4">
          <BookOpen size={11} />
          Getting Started
        </div>
        <h1 className="text-4xl font-bold text-slate-900 tracking-tight mb-3">
          PayForge Documentation
        </h1>
        <p className="text-lg text-slate-500 leading-relaxed">
          Welcome to the PayForge API documentation. Learn how to integrate our payment processing
          platform, manage transactions, and leverage ML-powered fraud detection.
        </p>
      </div>

      {/* Quick nav cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-12">
        {[
          {
            href: "/docs/api-reference",
            icon: Code2,
            title: "API Reference",
            desc: "Endpoints, parameters, and response formats",
            color: "indigo",
          },
          {
            href: "/docs/webhooks",
            icon: Webhook,
            title: "Webhooks",
            desc: "Real-time event notifications",
            color: "purple",
          },
          {
            href: "/docs/architecture",
            icon: Layers,
            title: "Architecture",
            desc: "Event sourcing, CQRS, and domain design",
            color: "emerald",
          },
          {
            href: "/docs/security",
            icon: Shield,
            title: "Security",
            desc: "Encryption, auth, and compliance",
            color: "amber",
          },
        ].map((card) => (
          <Link
            key={card.href}
            href={card.href}
            className="group flex items-start gap-3.5 rounded-xl border border-slate-200 p-4 hover:border-indigo-200 hover:shadow-sm transition-all"
          >
            <div className="rounded-lg bg-slate-100 p-2 group-hover:bg-indigo-50 transition-colors">
              <card.icon size={16} className="text-slate-500 group-hover:text-indigo-600 transition-colors" />
            </div>
            <div>
              <h3 className="text-sm font-semibold text-slate-900 group-hover:text-indigo-600 transition-colors flex items-center gap-1">
                {card.title}
                <ArrowRight size={12} className="opacity-0 group-hover:opacity-100 transition-opacity" />
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">{card.desc}</p>
            </div>
          </Link>
        ))}
      </div>

      {/* Quick Start */}
      <div className="mb-10">
        <h2 className="text-2xl font-bold text-slate-900 mb-6 flex items-center gap-2">
          Quick Start Guide
        </h2>
      </div>

      {/* Step 1 */}
      <section className="mb-10 relative">
        <div className="absolute left-3.5 top-10 bottom-0 w-px bg-slate-200" />
        <h2 className="text-lg font-semibold text-slate-900 mb-3 flex items-center gap-3">
          <span className="relative z-10 flex items-center justify-center w-7 h-7 rounded-full bg-indigo-600 text-white text-xs font-bold shadow-sm">
            1
          </span>
          Get Your API Keys
        </h2>
        <div className="pl-10">
          <p className="text-sm text-slate-600 mb-3">
            Sign in to your PayForge dashboard, navigate to <strong>Settings &rarr; API Keys</strong>,
            and create a new key pair. You&apos;ll receive a publishable key (<code className="text-xs bg-slate-100 px-1.5 py-0.5 rounded font-mono text-indigo-600">pk_test_...</code>)
            and a secret key (<code className="text-xs bg-slate-100 px-1.5 py-0.5 rounded font-mono text-indigo-600">sk_test_...</code>).
          </p>
          <div className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
            <strong>Security:</strong> Never expose your secret key in client-side code or version control.
            Use environment variables in production.
          </div>
        </div>
      </section>

      {/* Step 2 */}
      <section className="mb-10 relative">
        <div className="absolute left-3.5 top-10 bottom-0 w-px bg-slate-200" />
        <h2 className="text-lg font-semibold text-slate-900 mb-3 flex items-center gap-3">
          <span className="relative z-10 flex items-center justify-center w-7 h-7 rounded-full bg-indigo-600 text-white text-xs font-bold shadow-sm">
            2
          </span>
          Authenticate
        </h2>
        <div className="pl-10">
          <p className="text-sm text-slate-600 mb-3">
            All API requests require an <code className="text-xs bg-slate-100 px-1.5 py-0.5 rounded font-mono">Authorization</code> header
            with your API key as a Bearer token.
          </p>
          <CodeBlock
            language="bash"
            title="Authentication header"
            code={`curl https://api.payforge.dev/api/v1/transactions \\
  -H "Authorization: Bearer sk_test_your_secret_key" \\
  -H "Content-Type: application/json"`}
          />
        </div>
      </section>

      {/* Step 3 */}
      <section className="mb-10 relative">
        <div className="absolute left-3.5 top-10 bottom-0 w-px bg-slate-200" />
        <h2 className="text-lg font-semibold text-slate-900 mb-3 flex items-center gap-3">
          <span className="relative z-10 flex items-center justify-center w-7 h-7 rounded-full bg-indigo-600 text-white text-xs font-bold shadow-sm">
            3
          </span>
          Create Your First Transaction
        </h2>
        <div className="pl-10">
          <p className="text-sm text-slate-600 mb-3">
            Send a POST request to create a transaction. The payment will be automatically authorized
            and scored by the fraud engine. Include an idempotency key to safely retry requests.
          </p>
          <TabbedCodeBlock
            title="Create a transaction"
            tabs={[
              {
                label: "cURL",
                language: "bash",
                code: `curl -X POST "https://api.payforge.dev/api/v1/transactions" \\
  -H "Authorization: Bearer sk_test_..." \\
  -H "Content-Type: application/json" \\
  -H "X-Idempotency-Key: idem_abc123" \\
  -d '{
    "transaction": {
      "amount_cents": 5000,
      "currency": "USD",
      "card_last_four": "4242",
      "card_brand": "visa",
      "card_token": "tok_visa_4242",
      "idempotency_key": "idem_abc123"
    }
  }'`,
              },
              {
                label: "JavaScript",
                language: "javascript",
                code: `const response = await fetch("https://api.payforge.dev/api/v1/transactions", {
  method: "POST",
  headers: {
    "Authorization": "Bearer sk_test_...",
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    transaction: {
      amount_cents: 5000,
      currency: "USD",
      card_last_four: "4242",
      card_brand: "visa",
      card_token: "tok_visa_4242",
      idempotency_key: "idem_abc123",
    },
  }),
});

const { data } = await response.json();
console.log(data.id, data.status, data.fraud_score);`,
              },
              {
                label: "Python",
                language: "python",
                code: `import requests

response = requests.post(
    "https://api.payforge.dev/api/v1/transactions",
    headers={
        "Authorization": "Bearer sk_test_...",
        "Content-Type": "application/json",
    },
    json={
        "transaction": {
            "amount_cents": 5000,
            "currency": "USD",
            "card_last_four": "4242",
            "card_brand": "visa",
            "card_token": "tok_visa_4242",
            "idempotency_key": "idem_abc123",
        }
    },
)

data = response.json()["data"]
print(f"ID: {data['id']}, Status: {data['status']}")`,
              },
              {
                label: "Ruby",
                language: "ruby",
                code: `require "net/http"
require "json"

uri = URI("https://api.payforge.dev/api/v1/transactions")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request["Authorization"] = "Bearer sk_test_..."
request["Content-Type"] = "application/json"
request.body = {
  transaction: {
    amount_cents: 5000,
    currency: "USD",
    card_last_four: "4242",
    card_brand: "visa",
    card_token: "tok_visa_4242",
    idempotency_key: "idem_abc123"
  }
}.to_json

response = http.request(request)
data = JSON.parse(response.body)["data"]
puts "#{data["id"]}: #{data["status"]}"`,
              },
            ]}
          />
        </div>
      </section>

      {/* Step 4 */}
      <section className="mb-10 relative">
        <div className="absolute left-3.5 top-10 bottom-0 w-px bg-slate-200" />
        <h2 className="text-lg font-semibold text-slate-900 mb-3 flex items-center gap-3">
          <span className="relative z-10 flex items-center justify-center w-7 h-7 rounded-full bg-indigo-600 text-white text-xs font-bold shadow-sm">
            4
          </span>
          Handle the Response
        </h2>
        <div className="pl-10">
          <p className="text-sm text-slate-600 mb-3">
            Every response follows a consistent envelope format with <code className="text-xs bg-slate-100 px-1.5 py-0.5 rounded font-mono">data</code>,{" "}
            <code className="text-xs bg-slate-100 px-1.5 py-0.5 rounded font-mono">meta</code>, and{" "}
            <code className="text-xs bg-slate-100 px-1.5 py-0.5 rounded font-mono">links</code> fields.
          </p>
          <CodeBlock
            language="json"
            title="Response (201 Created)"
            code={`{
  "data": {
    "id": "a1b2c3d4-...",
    "merchant_id": "e5f6g7h8-...",
    "status": "captured",
    "amount": {
      "cents": 5000,
      "currency": "USD",
      "formatted": "$50.00"
    },
    "fee_cents": 175,
    "net_cents": 4825,
    "card_last_four": "4242",
    "card_brand": "visa",
    "fraud_score": "0.0312",
    "fraud_decision": "pass",
    "idempotency_key": "idem_abc123",
    "created_at": "2026-03-06T10:30:00Z"
  },
  "meta": {
    "request_id": "req_01DEF...",
    "processing_time_ms": 42,
    "idempotency_key": "idem_abc123"
  }
}`}
          />
        </div>
      </section>

      {/* Step 5 */}
      <section className="mb-10 relative">
        <h2 className="text-lg font-semibold text-slate-900 mb-3 flex items-center gap-3">
          <span className="relative z-10 flex items-center justify-center w-7 h-7 rounded-full bg-indigo-600 text-white text-xs font-bold shadow-sm">
            5
          </span>
          Capture & Manage
        </h2>
        <div className="pl-10">
          <p className="text-sm text-slate-600 mb-3">
            Authorized payments can be captured, refunded, or voided. The Saga orchestrator handles
            the full lifecycle automatically after creation — but you can also manage each step manually.
          </p>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-4">
            <CodeBlock
              language="bash"
              title="Capture"
              code={`POST /api/v1/transactions/:id/capture
{ "amount_cents": 5000 }`}
            />
            <CodeBlock
              language="bash"
              title="Refund"
              code={`POST /api/v1/transactions/:id/refund
{ "amount_cents": 2500 }`}
            />
            <CodeBlock
              language="bash"
              title="Void"
              code={`POST /api/v1/transactions/:id/void`}
            />
          </div>
        </div>
      </section>

      {/* Key Concepts */}
      <section className="mb-10 pt-6 border-t border-slate-200">
        <h2 className="text-2xl font-bold text-slate-900 mb-6">Key Concepts</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {[
            {
              icon: CreditCard,
              title: "Payment Lifecycle",
              desc: "Transactions flow through a deterministic state machine: initiated -> authorized -> captured -> settled. Each transition is an immutable event.",
            },
            {
              icon: Brain,
              title: "Fraud Scoring",
              desc: "Every transaction is scored by a LightGBM model (0.0 to 1.0). SHAP explanations show which features contributed to the score.",
            },
            {
              icon: Lock,
              title: "Idempotency",
              desc: "Include X-Idempotency-Key on POST requests. Retrying with the same key returns the original response without re-processing.",
            },
            {
              icon: Layers,
              title: "Event Sourcing",
              desc: "Every state change is an immutable event stored in Rails Event Store. Query /transactions/:id/events for a complete audit trail.",
            },
          ].map((item) => (
            <div
              key={item.title}
              className="rounded-xl border border-slate-200 p-5 hover:border-slate-300 transition-colors"
            >
              <div className="flex items-center gap-2.5 mb-2">
                <div className="rounded-lg bg-slate-100 p-1.5">
                  <item.icon size={14} className="text-slate-500" />
                </div>
                <h3 className="text-sm font-semibold text-slate-900">{item.title}</h3>
              </div>
              <p className="text-xs text-slate-500 leading-relaxed">{item.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Next steps */}
      <section className="rounded-xl bg-slate-50 border border-slate-200 p-6">
        <h3 className="text-base font-semibold text-slate-900 mb-4">What&apos;s Next?</h3>
        <div className="space-y-2.5">
          {[
            { href: "/docs/api-reference", label: "Explore the full API reference", desc: "All endpoints with request/response examples" },
            { href: "/docs/webhooks", label: "Set up webhooks", desc: "Receive real-time event notifications" },
            { href: "/docs/architecture", label: "Understand the architecture", desc: "Event sourcing, CQRS, and domain design" },
          ].map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="flex items-center justify-between rounded-lg bg-white border border-slate-200 px-4 py-3 hover:border-indigo-200 hover:shadow-sm transition-all group"
            >
              <div>
                <span className="text-sm font-medium text-slate-900 group-hover:text-indigo-600 transition-colors">
                  {link.label}
                </span>
                <p className="text-xs text-slate-500">{link.desc}</p>
              </div>
              <ArrowRight size={14} className="text-slate-400 group-hover:text-indigo-600 transition-colors" />
            </Link>
          ))}
        </div>
      </section>
    </article>
  );
}
