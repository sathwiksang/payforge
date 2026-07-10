"use client";

import dynamic from "next/dynamic";
import { CodeBlock } from "@/components/docs/code-block";
import { Layers, GitBranch, Database, Cpu, ArrowRight } from "lucide-react";

const ArchitectureDiagram = dynamic(
  () => import("@/components/interactive/architecture-diagram").then((m) => m.ArchitectureDiagram),
  { ssr: false }
);
const PaymentFlow = dynamic(
  () => import("@/components/interactive/payment-flow").then((m) => m.PaymentFlow),
  { ssr: false }
);
const FraudScoringDemo = dynamic(
  () => import("@/components/interactive/fraud-scoring-demo").then((m) => m.FraudScoringDemo),
  { ssr: false }
);
const LedgerVisualizer = dynamic(
  () => import("@/components/interactive/ledger-visualizer").then((m) => m.LedgerVisualizer),
  { ssr: false }
);

export default function ArchitecturePage() {
  return (
    <article className="max-w-4xl">
      <div className="mb-10">
        <div className="inline-flex items-center gap-1.5 rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-[11px] font-medium text-emerald-700 mb-4">
          <Layers size={11} />
          Platform
        </div>
        <h1 className="text-4xl font-bold text-slate-900 tracking-tight mb-3">Architecture</h1>
        <p className="text-lg text-slate-500 leading-relaxed">
          How PayForge processes payments using event sourcing, CQRS, saga orchestration, and double-entry bookkeeping.
          Explore the interactive diagrams below.
        </p>
      </div>

      {/* Interactive Architecture Diagram */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold text-slate-900 mb-4">System Overview</h2>
        <p className="text-sm text-slate-600 mb-6 leading-relaxed">
          PayForge is built as a <strong>modular monolith</strong> with domain-driven boundaries. Each domain
          (Payments, Ledger, Fraud, Merchants, Webhooks) is isolated with its own models, commands,
          and policies. Click on any domain below to explore its internals.
        </p>

        <ArchitectureDiagram />

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-6">
          {[
            { label: "5 Domains", desc: "Isolated with clear boundaries" },
            { label: "UUID PKs", desc: "All tables use UUID primary keys" },
            { label: "Event-Driven", desc: "Internal event bus for communication" },
          ].map((s) => (
            <div key={s.label} className="rounded-xl border border-slate-200 p-4 text-center">
              <div className="text-base font-bold text-slate-900">{s.label}</div>
              <div className="text-xs text-slate-500 mt-0.5">{s.desc}</div>
            </div>
          ))}
        </div>
      </section>

      {/* Interactive Payment Flow */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold text-slate-900 mb-4">Payment State Machine</h2>
        <p className="text-sm text-slate-600 mb-6 leading-relaxed">
          A payment moves through a deterministic state machine managed by the Saga orchestrator.
          Click each state to inspect its domain events and ledger entries, or press <strong>Play Flow</strong> to watch
          the full lifecycle animate.
        </p>

        <PaymentFlow />
      </section>

      {/* Event Sourcing */}
      <section className="mb-12">
        <div className="flex items-center gap-2.5 mb-4">
          <div className="rounded-lg bg-indigo-100 p-2">
            <GitBranch size={16} className="text-indigo-600" />
          </div>
          <h2 className="text-2xl font-bold text-slate-900">Event Sourcing</h2>
        </div>
        <p className="text-sm text-slate-600 mb-4 leading-relaxed">
          Every state change is captured as an immutable event using <strong>Rails Event Store</strong>. The current state
          of a payment is derived by replaying its event stream. This provides a complete audit trail
          and enables temporal queries — you can reconstruct the exact state of any transaction at any point in time.
        </p>
        <CodeBlock
          language="ruby"
          title="Publishing a domain event"
          code={`# When a payment is authorized, an event is published
event = Payments::Events::PaymentAuthorized.new(
  data: {
    transaction_id: transaction.id,
    amount_cents: transaction.amount_cents,
    currency: transaction.currency,
    auth_code: "A12345",
    occurred_at: Time.current
  }
)

# Published to a per-aggregate stream
Rails.configuration.event_store.publish(
  event,
  stream_name: "Payment$\#{transaction.id}"
)`}
        />
        <div className="mt-4 rounded-xl border border-blue-200 bg-blue-50 px-4 py-3 text-sm text-blue-800">
          <strong>Append-only streams:</strong> Events are never modified or deleted. Each transaction has its own
          stream. Subscribers react to events asynchronously — the fraud engine scores the transaction
          when <code className="text-xs bg-blue-100 px-1 py-0.5 rounded font-mono">PaymentAuthorized</code> is published.
        </div>
      </section>

      {/* CQRS */}
      <section className="mb-12">
        <div className="flex items-center gap-2.5 mb-4">
          <div className="rounded-lg bg-purple-100 p-2">
            <Database size={16} className="text-purple-600" />
          </div>
          <h2 className="text-2xl font-bold text-slate-900">CQRS Pattern</h2>
        </div>
        <p className="text-sm text-slate-600 mb-4 leading-relaxed">
          Command Query Responsibility Segregation separates write operations (commands) from read operations (queries).
          Commands go through domain services that enforce business rules, while queries read from optimized projections.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="rounded-xl border border-slate-200 p-5">
            <h3 className="text-sm font-bold text-slate-900 mb-3 flex items-center gap-2">
              <span className="h-2 w-2 rounded-full bg-indigo-500" />
              Commands (Writes)
            </h3>
            <ul className="text-sm text-slate-600 space-y-2">
              {["ProcessPayment", "CapturePayment", "RefundPayment", "VoidPayment", "ReviewFraudCase"].map((cmd) => (
                <li key={cmd} className="flex items-center gap-2">
                  <ArrowRight size={10} className="text-slate-400" />
                  <code className="text-xs font-mono text-indigo-600">{cmd}</code>
                </li>
              ))}
            </ul>
          </div>
          <div className="rounded-xl border border-slate-200 p-5">
            <h3 className="text-sm font-bold text-slate-900 mb-3 flex items-center gap-2">
              <span className="h-2 w-2 rounded-full bg-emerald-500" />
              Queries (Reads)
            </h3>
            <ul className="text-sm text-slate-600 space-y-2">
              {[
                "List transactions (filtered, paginated)",
                "Transaction detail + event stream",
                "Ledger entries per transaction",
                "Fraud statistics & analytics",
                "Merchant dashboard metrics",
              ].map((q) => (
                <li key={q} className="flex items-center gap-2">
                  <ArrowRight size={10} className="text-slate-400" />
                  <span className="text-xs">{q}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      {/* Interactive Double-Entry Ledger */}
      <section className="mb-12">
        <div className="flex items-center gap-2.5 mb-4">
          <div className="rounded-lg bg-emerald-100 p-2">
            <Database size={16} className="text-emerald-600" />
          </div>
          <h2 className="text-2xl font-bold text-slate-900">Double-Entry Ledger</h2>
        </div>
        <p className="text-sm text-slate-600 mb-6 leading-relaxed">
          Every financial movement creates balanced debit/credit entries across accounts.
          The ledger is <strong>append-only</strong> — corrections are made with reversing entries, never by modifying
          existing records. Watch how a payment flows through the accounting system:
        </p>

        <LedgerVisualizer />

        <div className="mt-6">
          <CodeBlock
            language="ruby"
            title="Ledger entry for a $50.00 captured payment (2.9% + $0.30 fee)"
            code={`# Total fee: $1.75 → merchant receives $48.25

DoubleEntryService.new.record_capture(transaction: transaction)

# Creates balanced entries:
#   Debit  merchant_receivable  $50.00  (money owed to merchant)
#   Credit payment_processing   $50.00  (payment cleared)
#   Credit merchant_revenue     $48.25  (net amount after fees)
#   Debit  platform_fees        $1.75   (PayForge's fee)

# Invariant: total debits == total credits (always)`}
          />
        </div>
      </section>

      {/* Interactive Fraud Scoring */}
      <section className="mb-12">
        <div className="flex items-center gap-2.5 mb-4">
          <div className="rounded-lg bg-rose-100 p-2">
            <Cpu size={16} className="text-rose-600" />
          </div>
          <h2 className="text-2xl font-bold text-slate-900">Fraud Detection Engine</h2>
        </div>
        <p className="text-sm text-slate-600 mb-6 leading-relaxed">
          Every transaction is evaluated by a <strong>LightGBM</strong> model trained on 200K+ synthetic transactions
          (2% fraud rate, 5-fold cross-validation, AUC 1.0). Try different scenarios below to see how
          the model scores transactions with SHAP explainability:
        </p>

        <FraudScoringDemo />

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-6 mb-4">
          {[
            { label: "Risk Score", value: "0.0–1.0", desc: "ML probability of fraud" },
            { label: "Decisions", value: "pass / review / block", desc: "Based on configurable thresholds" },
            { label: "Latency", value: "<5ms", desc: "Feature extraction + scoring" },
            { label: "Explainability", value: "SHAP values", desc: "Per-feature contribution scores" },
          ].map((s) => (
            <div key={s.label} className="rounded-xl border border-slate-200 p-4">
              <div className="text-xs text-slate-400 mb-1">{s.label}</div>
              <div className="text-sm font-bold text-slate-900">{s.value}</div>
              <div className="text-xs text-slate-500 mt-0.5">{s.desc}</div>
            </div>
          ))}
        </div>
      </section>

      {/* Tech Stack */}
      <section className="mb-10">
        <h2 className="text-2xl font-bold text-slate-900 mb-6">Technology Stack</h2>
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {[
            { label: "Backend", value: "Ruby on Rails 8.1", desc: "API mode, modular monolith" },
            { label: "Frontend", value: "Next.js 16", desc: "React 19, TypeScript, Tailwind 4" },
            { label: "Database", value: "PostgreSQL", desc: "UUID PKs, JSONB, GIN indexes" },
            { label: "Cache & Jobs", value: "Redis + Sidekiq", desc: "Caching, background processing" },
            { label: "Event Store", value: "Rails Event Store", desc: "Append-only event streams" },
            { label: "Auth", value: "Devise + JWT", desc: "MFA, API keys, role-based access" },
            { label: "Encryption", value: "Lockbox", desc: "AES-256-GCM + blind index" },
            { label: "Fraud ML", value: "LightGBM + SHAP", desc: "Python sidecar, 200K training" },
            { label: "Audit", value: "PaperTrail", desc: "Full change history on all models" },
          ].map((item) => (
            <div key={item.label} className="rounded-xl border border-slate-200 p-4 hover:border-slate-300 transition-colors">
              <div className="text-[10px] uppercase tracking-wider text-slate-400 mb-1">{item.label}</div>
              <div className="text-sm font-semibold text-slate-900">{item.value}</div>
              <div className="text-xs text-slate-500 mt-0.5">{item.desc}</div>
            </div>
          ))}
        </div>
      </section>
    </article>
  );
}
