"use client";

import Link from "next/link";
import dynamic from "next/dynamic";
import { motion } from "framer-motion";
import {
  Zap,
  ShieldCheck,
  BarChart3,
  BookOpen,
  ArrowRight,
  CreditCard,
  Brain,
  Layers,
  Lock,
  Webhook,
  GitBranch,
  ChevronRight,
} from "lucide-react";

const ArchitectureDiagram = dynamic(
  () => import("@/components/interactive/architecture-diagram").then((m) => m.ArchitectureDiagram),
  { ssr: false }
);

const TransactionTicker = dynamic(
  () => import("@/components/interactive/transaction-ticker").then((m) => m.TransactionTicker),
  { ssr: false }
);

const fadeUp = {
  hidden: { opacity: 0, y: 30 },
  visible: (i: number) => ({
    opacity: 1,
    y: 0,
    transition: { delay: i * 0.1, duration: 0.5, ease: "easeOut" as const },
  }),
};

const FEATURES = [
  {
    icon: CreditCard,
    title: "Payment Processing",
    description:
      "Full lifecycle management — authorize, capture, refund, void. Event-sourced state machine ensures every transition is auditable and deterministic.",
    gradient: "from-indigo-500 to-blue-600",
  },
  {
    icon: Brain,
    title: "ML Fraud Detection",
    description:
      "LightGBM model trained on 200K+ synthetic transactions achieves AUC 1.0. SHAP explanations provide feature-level transparency for every risk score.",
    gradient: "from-purple-500 to-pink-600",
  },
  {
    icon: Layers,
    title: "Double-Entry Ledger",
    description:
      "Every financial movement creates balanced debit/credit entries. Append-only design with database-level invariants ensures the books always balance.",
    gradient: "from-emerald-500 to-teal-600",
  },
  {
    icon: Lock,
    title: "Security-First Architecture",
    description:
      "AES-256-GCM encryption at rest, blind index search, JWT + MFA authentication, rate limiting, and PCI DSS 4.0-aware controls. Brakeman clean.",
    gradient: "from-amber-500 to-orange-600",
  },
  {
    icon: GitBranch,
    title: "Event Sourcing & CQRS",
    description:
      "Rails Event Store captures every state change as an immutable event. CQRS separates read/write models. Saga orchestration manages complex workflows.",
    gradient: "from-cyan-500 to-blue-600",
  },
  {
    icon: Webhook,
    title: "Webhook Delivery",
    description:
      "Real-time notifications with HMAC-SHA256 signatures, exponential backoff retry (5 attempts over 24h), and delivery tracking in the dashboard.",
    gradient: "from-rose-500 to-red-600",
  },
];

const TECH_STACK = [
  { name: "Ruby on Rails 8.1", category: "Backend" },
  { name: "Next.js 16 + React 19", category: "Frontend" },
  { name: "PostgreSQL", category: "Database" },
  { name: "Redis + Sidekiq", category: "Cache / Queues" },
  { name: "LightGBM + SHAP", category: "ML Engine" },
  { name: "Rails Event Store", category: "Event Sourcing" },
  { name: "Devise + JWT", category: "Authentication" },
  { name: "Lockbox + Blind Index", category: "Encryption" },
];

const STATS = [
  { value: "418+", label: "Test Cases" },
  { value: "0", label: "Brakeman Warnings" },
  { value: "<5ms", label: "Fraud Scoring" },
  { value: "100%", label: "Mutation Coverage" },
];

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-white">
      {/* Navigation */}
      <nav className="fixed top-0 left-0 right-0 z-50 border-b border-slate-100 bg-white/80 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
          <Link href="/" className="flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-indigo-600">
              <Zap size={18} className="text-white" />
            </div>
            <span className="text-lg font-bold text-slate-900 tracking-tight">PayForge</span>
          </Link>
          <div className="hidden md:flex items-center gap-8">
            <Link href="#features" className="text-sm text-slate-600 hover:text-slate-900 transition-colors">
              Features
            </Link>
            <Link href="#architecture" className="text-sm text-slate-600 hover:text-slate-900 transition-colors">
              Architecture
            </Link>
            <Link href="/docs" className="text-sm text-slate-600 hover:text-slate-900 transition-colors">
              Documentation
            </Link>
          </div>
          <div className="flex items-center gap-2 sm:gap-3">
            <a
              href="https://github.com/sathwiksang/payforge"
              target="_blank"
              rel="noreferrer"
              aria-label="View source on GitHub"
              className="inline-flex items-center gap-1.5 rounded-lg px-2 sm:px-3 py-2 text-sm font-medium text-slate-600 hover:text-slate-900 hover:bg-slate-100 transition-colors"
            >
              <svg
                viewBox="0 0 16 16"
                width={16}
                height={16}
                fill="currentColor"
                aria-hidden="true"
              >
                <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
              </svg>
              <span className="hidden sm:inline">View source</span>
            </a>
            <Link
              href="/login"
              className="text-sm font-medium text-slate-700 hover:text-slate-900 transition-colors"
            >
              Sign In
            </Link>
            <Link
              href="/dashboard"
              className="inline-flex items-center gap-1.5 rounded-lg bg-indigo-600 px-3 sm:px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 transition-colors shadow-sm"
            >
              Dashboard
              <ArrowRight size={14} className="hidden sm:block" />
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="relative pt-32 pb-20 overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-b from-indigo-50/50 via-white to-white" />
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[600px] bg-gradient-to-r from-indigo-200/30 via-purple-200/20 to-pink-200/30 rounded-full blur-3xl opacity-60" />

        <div className="relative mx-auto max-w-6xl px-6">
          <motion.div
            initial="hidden"
            animate="visible"
            className="mx-auto max-w-3xl text-center"
          >
            <motion.div variants={fadeUp} custom={0} className="mb-6">
              <span className="inline-flex items-center gap-1.5 rounded-full border border-indigo-200 bg-indigo-50 px-4 py-1.5 text-xs font-medium text-indigo-700">
                <ShieldCheck size={12} />
                Production-Grade Payment Infrastructure
              </span>
            </motion.div>

            <motion.h1
              variants={fadeUp}
              custom={1}
              className="text-5xl sm:text-6xl font-bold text-slate-900 tracking-tight leading-tight"
            >
              Intelligent Payment
              <br />
              <span className="bg-gradient-to-r from-indigo-600 via-purple-600 to-indigo-600 bg-clip-text text-transparent">
                Processing Platform
              </span>
            </motion.h1>

            <motion.p
              variants={fadeUp}
              custom={2}
              className="mt-6 text-lg text-slate-600 leading-relaxed max-w-2xl mx-auto"
            >
              Event-sourced payment gateway with real-time ML fraud detection,
              double-entry ledger, and PCI DSS 4.0-aware security controls.
              Built with Rails 8, Next.js 16, and LightGBM.
            </motion.p>

            <motion.div
              variants={fadeUp}
              custom={3}
              className="mt-10 flex items-center justify-center gap-4"
            >
              <Link
                href="/dashboard"
                className="inline-flex items-center gap-2 rounded-xl bg-indigo-600 px-6 py-3 text-sm font-semibold text-white hover:bg-indigo-700 transition-all shadow-lg shadow-indigo-200 hover:shadow-xl hover:shadow-indigo-200"
              >
                <BarChart3 size={16} />
                Open Dashboard
              </Link>
              <Link
                href="/docs"
                className="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-6 py-3 text-sm font-semibold text-slate-700 hover:border-slate-300 hover:bg-slate-50 transition-all"
              >
                <BookOpen size={16} />
                Read the Docs
              </Link>
            </motion.div>
          </motion.div>

          {/* Live Transaction Ticker */}
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.5, duration: 0.6 }}
            className="mt-16 mx-auto max-w-md"
          >
            <TransactionTicker />
          </motion.div>

          {/* Stats Bar */}
          <motion.div
            initial={{ opacity: 0, y: 40 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.7, duration: 0.6 }}
            className="mt-12 mx-auto max-w-3xl"
          >
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              {STATS.map((stat) => (
                <div
                  key={stat.label}
                  className="rounded-xl border border-slate-100 bg-white/80 backdrop-blur p-5 text-center shadow-sm"
                >
                  <div className="text-2xl font-bold text-slate-900 tabular-nums">
                    {stat.value}
                  </div>
                  <div className="mt-1 text-xs text-slate-500">{stat.label}</div>
                </div>
              ))}
            </div>
          </motion.div>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="py-24 bg-slate-50/50">
        <div className="mx-auto max-w-6xl px-6">
          <div className="text-center mb-16">
            <h2 className="text-3xl font-bold text-slate-900 tracking-tight">
              Production-Grade Engineering
            </h2>
            <p className="mt-3 text-base text-slate-600 max-w-2xl mx-auto">
              Every component is built to the same standards you would find in a real payment processor —
              from cryptographic security to ML-powered fraud intelligence.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {FEATURES.map((feature, i) => (
              <motion.div
                key={feature.title}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-50px" }}
                transition={{ delay: i * 0.08, duration: 0.4 }}
                className="group rounded-2xl border border-slate-200 bg-white p-6 hover:border-slate-300 hover:shadow-lg transition-all duration-300"
              >
                <div
                  className={`inline-flex h-11 w-11 items-center justify-center rounded-xl bg-gradient-to-br ${feature.gradient} shadow-sm`}
                >
                  <feature.icon size={20} className="text-white" />
                </div>
                <h3 className="mt-4 text-base font-semibold text-slate-900">
                  {feature.title}
                </h3>
                <p className="mt-2 text-sm text-slate-600 leading-relaxed">
                  {feature.description}
                </p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Architecture Overview */}
      <section id="architecture" className="py-24">
        <div className="mx-auto max-w-6xl px-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
            <div>
              <h2 className="text-3xl font-bold text-slate-900 tracking-tight">
                Modular Monolith Architecture
              </h2>
              <p className="mt-4 text-base text-slate-600 leading-relaxed">
                PayForge is structured as a modular monolith with domain-driven boundaries.
                Each domain — Payments, Ledger, Fraud, Merchants, Webhooks — is isolated
                with its own models, services, and policies, communicating through an
                internal event bus powered by Rails Event Store.
              </p>

              <div className="mt-8 space-y-3">
                {[
                  "Event-sourced payment aggregates with replay capability",
                  "CQRS read models for optimized queries",
                  "Saga orchestration for multi-step workflows",
                  "Double-entry ledger with database-level invariants",
                  "Append-only audit trail via PaperTrail + events",
                ].map((item) => (
                  <div key={item} className="flex items-start gap-3">
                    <ChevronRight
                      size={16}
                      className="mt-0.5 text-indigo-600 flex-shrink-0"
                    />
                    <span className="text-sm text-slate-700">{item}</span>
                  </div>
                ))}
              </div>

              <div className="mt-8">
                <Link
                  href="/docs/architecture"
                  className="inline-flex items-center gap-1.5 text-sm font-medium text-indigo-600 hover:text-indigo-700 transition-colors"
                >
                  Read Architecture Docs
                  <ArrowRight size={14} />
                </Link>
              </div>
            </div>

            {/* Interactive Architecture Diagram */}
            <div className="rounded-2xl border border-slate-200 bg-white p-2 shadow-2xl">
              <ArchitectureDiagram />
            </div>
          </div>
        </div>
      </section>

      {/* Tech Stack */}
      <section className="py-24 bg-slate-50/50">
        <div className="mx-auto max-w-6xl px-6">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-slate-900 tracking-tight">
              Technology Stack
            </h2>
            <p className="mt-3 text-base text-slate-600">
              Built with modern, battle-tested technologies
            </p>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 max-w-3xl mx-auto">
            {TECH_STACK.map((tech) => (
              <div
                key={tech.name}
                className="rounded-xl border border-slate-200 bg-white p-4 text-center hover:border-indigo-200 hover:shadow-sm transition-all"
              >
                <div className="text-[10px] uppercase tracking-wider text-slate-400 mb-1">
                  {tech.category}
                </div>
                <div className="text-sm font-semibold text-slate-900">{tech.name}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-24">
        <div className="mx-auto max-w-6xl px-6">
          <div className="relative rounded-3xl bg-gradient-to-br from-indigo-600 via-indigo-700 to-purple-800 p-12 md:p-16 text-center overflow-hidden">
            <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxnIGZpbGw9IiNmZmYiIGZpbGwtb3BhY2l0eT0iLjA1Ij48cGF0aCBkPSJNMzYgMzRoLTJ2LTRoMnYtMmgtNHYyaC0ydjRoMnYyaDR2LTJ6Ii8+PC9nPjwvZz48L3N2Zz4=')] opacity-40" />
            <div className="relative">
              <h2 className="text-3xl md:text-4xl font-bold text-white tracking-tight">
                Explore the Platform
              </h2>
              <p className="mt-4 text-base text-indigo-100 max-w-xl mx-auto">
                Sign in with the demo account to explore real-time dashboards, process test
                payments, and review ML fraud scoring with SHAP explanations.
              </p>
              <div className="mt-8 flex items-center justify-center gap-4 flex-wrap">
                <Link
                  href="/dashboard"
                  className="inline-flex items-center gap-2 rounded-xl bg-white px-6 py-3 text-sm font-semibold text-indigo-700 hover:bg-indigo-50 transition-colors shadow-lg"
                >
                  <BarChart3 size={16} />
                  Open Dashboard
                </Link>
                <Link
                  href="/docs/api-reference"
                  className="inline-flex items-center gap-2 rounded-xl border border-white/20 bg-white/10 px-6 py-3 text-sm font-semibold text-white hover:bg-white/20 transition-colors backdrop-blur"
                >
                  <BookOpen size={16} />
                  API Reference
                </Link>
              </div>
              <div className="mt-6 text-xs text-indigo-200">
                Demo: admin@payforge.dev / PayForge2026Secure
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-slate-100 py-12">
        <div className="mx-auto max-w-6xl px-6">
          <div className="flex flex-col md:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-2.5">
              <div className="flex h-7 w-7 items-center justify-center rounded-md bg-indigo-600">
                <Zap size={14} className="text-white" />
              </div>
              <span className="text-sm font-bold text-slate-900">PayForge</span>
            </div>
            <div className="flex items-center gap-6 text-sm text-slate-500">
              <Link href="/docs" className="hover:text-slate-700 transition-colors">
                Documentation
              </Link>
              <Link href="/docs/api-reference" className="hover:text-slate-700 transition-colors">
                API Reference
              </Link>
              <Link href="/docs/architecture" className="hover:text-slate-700 transition-colors">
                Architecture
              </Link>
              <Link href="/docs/security" className="hover:text-slate-700 transition-colors">
                Security
              </Link>
            </div>
          </div>
          <div className="mt-6 text-center text-xs text-slate-400">
            Built with Rails 8.1, Next.js 16, PostgreSQL, LightGBM, and Redis
          </div>
        </div>
      </footer>
    </div>
  );
}
