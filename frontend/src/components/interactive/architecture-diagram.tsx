"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  CreditCard,
  Brain,
  Building2,
  BookOpen,
  Webhook,
  Database,
  Shield,
  X,
  Zap,
} from "lucide-react";

interface DomainNode {
  id: string;
  label: string;
  icon: typeof CreditCard;
  color: string;
  bgColor: string;
  borderColor: string;
  x: number;
  y: number;
  description: string;
  details: string[];
}

const DOMAINS: DomainNode[] = [
  {
    id: "gateway",
    label: "API Gateway",
    icon: Shield,
    color: "text-slate-600",
    bgColor: "bg-slate-100",
    borderColor: "border-slate-300",
    x: 50,
    y: 5,
    description: "Entry point for all API requests",
    details: [
      "JWT + API Key authentication",
      "Rack::Attack rate limiting (100 req/min)",
      "CORS policy enforcement",
      "Idempotency key middleware",
      "Request correlation IDs",
    ],
  },
  {
    id: "payments",
    label: "Payments",
    icon: CreditCard,
    color: "text-indigo-600",
    bgColor: "bg-indigo-50",
    borderColor: "border-indigo-200",
    x: 15,
    y: 35,
    description: "Core payment processing domain",
    details: [
      "Event-sourced aggregates",
      "Saga orchestration engine",
      "State machine transitions",
      "Authorize → Capture → Settle",
      "Partial refunds & voids",
    ],
  },
  {
    id: "fraud",
    label: "Fraud Engine",
    icon: Brain,
    color: "text-purple-600",
    bgColor: "bg-purple-50",
    borderColor: "border-purple-200",
    x: 50,
    y: 35,
    description: "ML-powered fraud detection",
    details: [
      "LightGBM model (AUC 1.0)",
      "Real-time scoring (<5ms)",
      "SHAP explainability",
      "Velocity checks & rules",
      "Case management queue",
    ],
  },
  {
    id: "merchants",
    label: "Merchants",
    icon: Building2,
    color: "text-emerald-600",
    bgColor: "bg-emerald-50",
    borderColor: "border-emerald-200",
    x: 85,
    y: 35,
    description: "Merchant profiles & analytics",
    details: [
      "Profile management",
      "Fee calculation engine",
      "Analytics dashboards",
      "Account balances",
      "Risk tier classification",
    ],
  },
  {
    id: "ledger",
    label: "Ledger",
    icon: BookOpen,
    color: "text-amber-600",
    bgColor: "bg-amber-50",
    borderColor: "border-amber-200",
    x: 25,
    y: 65,
    description: "Double-entry bookkeeping",
    details: [
      "Balanced debit/credit entries",
      "Append-only (immutable)",
      "DB-level invariants",
      "Multi-account transfers",
      "Reconciliation-ready",
    ],
  },
  {
    id: "webhooks",
    label: "Webhooks",
    icon: Webhook,
    color: "text-rose-600",
    bgColor: "bg-rose-50",
    borderColor: "border-rose-200",
    x: 75,
    y: 65,
    description: "Event delivery & notifications",
    details: [
      "HMAC-SHA256 signatures",
      "Exponential backoff retry",
      "5 attempts over 24 hours",
      "Delivery tracking",
      "12 event types",
    ],
  },
  {
    id: "storage",
    label: "PostgreSQL + Redis",
    icon: Database,
    color: "text-cyan-600",
    bgColor: "bg-cyan-50",
    borderColor: "border-cyan-200",
    x: 50,
    y: 90,
    description: "Persistence & caching layer",
    details: [
      "PostgreSQL: Events, ledger, data",
      "UUID primary keys everywhere",
      "GIN indexes on JSONB",
      "Redis: Cache, sessions, jobs",
      "Sidekiq for async processing",
    ],
  },
];

const CONNECTIONS: { from: string; to: string; animated?: boolean }[] = [
  { from: "gateway", to: "payments", animated: true },
  { from: "gateway", to: "fraud" },
  { from: "gateway", to: "merchants" },
  { from: "payments", to: "ledger", animated: true },
  { from: "payments", to: "webhooks" },
  { from: "fraud", to: "payments" },
  { from: "ledger", to: "storage" },
  { from: "webhooks", to: "storage" },
  { from: "payments", to: "storage" },
  { from: "fraud", to: "storage" },
  { from: "merchants", to: "storage" },
];

function getCenter(node: DomainNode) {
  return { x: node.x, y: node.y + 4 };
}

export function ArchitectureDiagram() {
  const [selected, setSelected] = useState<DomainNode | null>(null);
  const [hovered, setHovered] = useState<string | null>(null);

  return (
    <div className="overflow-x-auto">
    <div className="relative min-w-[480px]">
      {/* SVG connections */}
      <svg
        className="absolute inset-0 w-full h-full pointer-events-none"
        viewBox="0 0 100 100"
        preserveAspectRatio="none"
        style={{ zIndex: 0 }}
      >
        <defs>
          <linearGradient id="flowGrad" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="#6366F1" stopOpacity="0.1" />
            <stop offset="50%" stopColor="#6366F1" stopOpacity="0.4" />
            <stop offset="100%" stopColor="#6366F1" stopOpacity="0.1" />
          </linearGradient>
        </defs>
        {CONNECTIONS.map((conn, i) => {
          const from = DOMAINS.find((d) => d.id === conn.from)!;
          const to = DOMAINS.find((d) => d.id === conn.to)!;
          const c1 = getCenter(from);
          const c2 = getCenter(to);
          const isHighlight = hovered === conn.from || hovered === conn.to;
          return (
            <line
              key={i}
              x1={`${c1.x}%`}
              y1={`${c1.y}%`}
              x2={`${c2.x}%`}
              y2={`${c2.y}%`}
              stroke={isHighlight ? "#6366F1" : "#E2E8F0"}
              strokeWidth={isHighlight ? "0.4" : "0.2"}
              strokeDasharray={conn.animated ? "1 1" : undefined}
              className="transition-all duration-300"
            >
              {conn.animated && (
                <animate
                  attributeName="stroke-dashoffset"
                  values="0;-4"
                  dur="1.5s"
                  repeatCount="indefinite"
                />
              )}
            </line>
          );
        })}
      </svg>

      {/* Domain nodes */}
      <div className="relative grid grid-rows-[auto_1fr_1fr_auto] gap-4 min-h-[480px] py-4">
        {/* Row 1: Gateway */}
        <div className="flex justify-center">
          <DomainCard
            node={DOMAINS[0]}
            isHovered={hovered === DOMAINS[0].id}
            onHover={setHovered}
            onClick={setSelected}
          />
        </div>

        {/* Row 2: Payments, Fraud, Merchants */}
        <div className="flex justify-between items-center px-2">
          <DomainCard node={DOMAINS[1]} isHovered={hovered === DOMAINS[1].id} onHover={setHovered} onClick={setSelected} />
          <DomainCard node={DOMAINS[2]} isHovered={hovered === DOMAINS[2].id} onHover={setHovered} onClick={setSelected} />
          <DomainCard node={DOMAINS[3]} isHovered={hovered === DOMAINS[3].id} onHover={setHovered} onClick={setSelected} />
        </div>

        {/* Row 3: Ledger, Webhooks */}
        <div className="flex justify-around items-center px-12">
          <DomainCard node={DOMAINS[4]} isHovered={hovered === DOMAINS[4].id} onHover={setHovered} onClick={setSelected} />
          <DomainCard node={DOMAINS[5]} isHovered={hovered === DOMAINS[5].id} onHover={setHovered} onClick={setSelected} />
        </div>

        {/* Row 4: Storage */}
        <div className="flex justify-center">
          <DomainCard node={DOMAINS[6]} isHovered={hovered === DOMAINS[6].id} onHover={setHovered} onClick={setSelected} wide />
        </div>
      </div>

      {/* Animated data flow particles */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden">
        {[0, 1, 2].map((i) => (
          <motion.div
            key={i}
            className="absolute w-1.5 h-1.5 rounded-full bg-indigo-400/60"
            animate={{
              x: ["45%", "15%", "25%", "50%"],
              y: ["12%", "38%", "68%", "92%"],
            }}
            transition={{
              duration: 4,
              delay: i * 1.3,
              repeat: Infinity,
              ease: "linear",
            }}
          />
        ))}
      </div>

      {/* Detail panel */}
      <AnimatePresence>
        {selected && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 10 }}
            className="absolute inset-x-0 bottom-0 z-20"
          >
            <div className={`rounded-xl border-2 ${selected.borderColor} bg-white p-5 shadow-xl mx-4`}>
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-3">
                  <div className={`rounded-lg ${selected.bgColor} p-2`}>
                    <selected.icon size={18} className={selected.color} />
                  </div>
                  <div>
                    <h3 className="text-base font-bold text-slate-900">{selected.label}</h3>
                    <p className="text-sm text-slate-500">{selected.description}</p>
                  </div>
                </div>
                <button onClick={() => setSelected(null)} className="text-slate-400 hover:text-slate-600">
                  <X size={16} />
                </button>
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {selected.details.map((detail) => (
                  <div key={detail} className="flex items-center gap-2 text-xs text-slate-600">
                    <Zap size={10} className={selected.color} />
                    {detail}
                  </div>
                ))}
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
    </div>
  );
}

function DomainCard({
  node,
  isHovered,
  onHover,
  onClick,
  wide = false,
}: {
  node: DomainNode;
  isHovered: boolean;
  onHover: (id: string | null) => void;
  onClick: (node: DomainNode) => void;
  wide?: boolean;
}) {
  return (
    <motion.button
      whileHover={{ scale: 1.05, y: -2 }}
      whileTap={{ scale: 0.98 }}
      onMouseEnter={() => onHover(node.id)}
      onMouseLeave={() => onHover(null)}
      onClick={() => onClick(node)}
      className={`relative rounded-xl border-2 ${
        isHovered ? node.borderColor : "border-slate-200"
      } ${node.bgColor} px-5 py-3.5 transition-all duration-200 shadow-sm hover:shadow-lg cursor-pointer ${
        wide ? "min-w-[220px]" : "min-w-[140px]"
      }`}
    >
      <div className="flex items-center gap-2.5">
        <node.icon size={16} className={node.color} />
        <span className="text-sm font-semibold text-slate-900">{node.label}</span>
      </div>
      <p className="mt-1 text-[11px] text-slate-500 text-left">{node.description}</p>
      {isHovered && (
        <motion.div
          layoutId="arch-highlight"
          className={`absolute inset-0 rounded-xl border-2 ${node.borderColor} pointer-events-none`}
          transition={{ type: "spring", stiffness: 400, damping: 30 }}
        />
      )}
    </motion.button>
  );
}
