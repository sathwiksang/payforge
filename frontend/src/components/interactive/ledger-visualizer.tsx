"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { BookOpen, ArrowRight, DollarSign, Plus, Equal, ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";

interface LedgerEntry {
  id: string;
  debitAccount: string;
  creditAccount: string;
  amount: string;
  description: string;
}

interface LedgerStep {
  id: string;
  label: string;
  description: string;
  color: string;
  entries: LedgerEntry[];
  accounts: Record<string, { balance: string; type: "debit" | "credit" }>;
}

const STEPS: LedgerStep[] = [
  {
    id: "capture",
    label: "1. Payment Captured",
    description: "Funds secured from cardholder — $50.00 moves from processing to merchant receivable",
    color: "text-blue-600",
    entries: [
      { id: "e1", debitAccount: "merchant_receivable", creditAccount: "payment_processing", amount: "$50.00", description: "Payment capture" },
    ],
    accounts: {
      payment_processing: { balance: "$50.00 CR", type: "credit" },
      merchant_receivable: { balance: "$50.00 DR", type: "debit" },
      platform_fees: { balance: "$0.00", type: "debit" },
      merchant_payout: { balance: "$0.00", type: "debit" },
    },
  },
  {
    id: "fees",
    label: "2. Fees Calculated",
    description: "Platform fee of $1.75 (2.9% + $0.30) deducted — merchant net: $48.25",
    color: "text-amber-600",
    entries: [
      { id: "e2", debitAccount: "merchant_receivable", creditAccount: "payment_processing", amount: "$50.00", description: "Payment capture" },
      { id: "e3", debitAccount: "platform_fees", creditAccount: "merchant_receivable", amount: "$1.75", description: "Processing fee (2.9% + $0.30)" },
    ],
    accounts: {
      payment_processing: { balance: "$50.00 CR", type: "credit" },
      merchant_receivable: { balance: "$48.25 DR", type: "debit" },
      platform_fees: { balance: "$1.75 DR", type: "debit" },
      merchant_payout: { balance: "$0.00", type: "debit" },
    },
  },
  {
    id: "settlement",
    label: "3. Settlement",
    description: "Net amount transferred to merchant's bank account",
    color: "text-emerald-600",
    entries: [
      { id: "e4", debitAccount: "merchant_receivable", creditAccount: "payment_processing", amount: "$50.00", description: "Payment capture" },
      { id: "e5", debitAccount: "platform_fees", creditAccount: "merchant_receivable", amount: "$1.75", description: "Processing fee" },
      { id: "e6", debitAccount: "merchant_payout", creditAccount: "merchant_receivable", amount: "$48.25", description: "Settlement payout" },
    ],
    accounts: {
      payment_processing: { balance: "$50.00 CR", type: "credit" },
      merchant_receivable: { balance: "$0.00", type: "debit" },
      platform_fees: { balance: "$1.75 DR", type: "debit" },
      merchant_payout: { balance: "$48.25 DR", type: "debit" },
    },
  },
];

export function LedgerVisualizer() {
  const [activeStep, setActiveStep] = useState(0);
  const [isAnimating, setIsAnimating] = useState(false);

  const step = STEPS[activeStep];

  function playAnimation() {
    setActiveStep(0);
    setIsAnimating(true);
    let current = 0;
    const interval = setInterval(() => {
      current++;
      if (current >= STEPS.length) {
        clearInterval(interval);
        setIsAnimating(false);
        return;
      }
      setActiveStep(current);
    }, 1500);
  }

  return (
    <div className="rounded-2xl border border-slate-200 bg-white overflow-hidden shadow-sm">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 bg-slate-50 border-b border-slate-200">
        <div className="flex items-center gap-2.5">
          <BookOpen size={16} className="text-emerald-600" />
          <div>
            <h3 className="text-base font-bold text-slate-900">Double-Entry Ledger</h3>
            <p className="text-xs text-slate-500 mt-0.5">Watch how a $50.00 payment flows through the accounting system</p>
          </div>
        </div>
        <button
          onClick={playAnimation}
          disabled={isAnimating}
          className="rounded-lg bg-emerald-600 px-3.5 py-1.5 text-xs font-semibold text-white hover:bg-emerald-700 disabled:opacity-50 transition-colors"
        >
          {isAnimating ? "Playing..." : "Play Animation"}
        </button>
      </div>

      {/* Step Selector */}
      <div className="flex border-b border-slate-200">
        {STEPS.map((s, i) => (
          <button
            key={s.id}
            onClick={() => { setActiveStep(i); setIsAnimating(false); }}
            className={cn(
              "flex-1 py-3 px-4 text-xs font-semibold transition-all border-b-2",
              i === activeStep
                ? `${s.color} border-current bg-slate-50`
                : i < activeStep
                ? "text-slate-500 border-transparent"
                : "text-slate-300 border-transparent"
            )}
          >
            {s.label}
          </button>
        ))}
      </div>

      <div className="p-6">
        {/* Description */}
        <motion.div
          key={activeStep}
          initial={{ opacity: 0, y: 5 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-6 rounded-lg bg-slate-50 border border-slate-100 px-4 py-3"
        >
          <p className="text-sm text-slate-700">{step.description}</p>
        </motion.div>

        {/* Journal Entries */}
        <div className="mb-6">
          <h4 className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">
            Journal Entries
          </h4>
          <div className="rounded-xl border border-slate-200 overflow-hidden">
            <div className="grid grid-cols-[1fr_1fr_100px] bg-slate-100 px-4 py-2 text-[10px] font-bold uppercase tracking-wider text-slate-500">
              <span>Debit Account</span>
              <span>Credit Account</span>
              <span className="text-right">Amount</span>
            </div>
            <AnimatePresence mode="sync">
              {step.entries.map((entry, i) => (
                <motion.div
                  key={entry.id}
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  transition={{ delay: i * 0.15 }}
                  className="border-t border-slate-100"
                >
                  <div className="grid grid-cols-[1fr_1fr_100px] px-4 py-3 items-center">
                    <div className="flex items-center gap-2">
                      <span className="h-2 w-2 rounded-full bg-blue-500 flex-shrink-0" />
                      <code className="text-xs font-mono text-slate-800">{entry.debitAccount}</code>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="h-2 w-2 rounded-full bg-emerald-500 flex-shrink-0" />
                      <code className="text-xs font-mono text-slate-800">{entry.creditAccount}</code>
                    </div>
                    <div className="text-right">
                      <span className="text-sm font-bold text-slate-900 font-mono">{entry.amount}</span>
                    </div>
                  </div>
                  <div className="px-4 pb-2 -mt-1">
                    <span className="text-[11px] text-slate-400">{entry.description}</span>
                  </div>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        </div>

        {/* Account Balances */}
        <div className="mb-4">
          <h4 className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">
            Account Balances
          </h4>
          <div className="grid grid-cols-2 gap-3">
            {Object.entries(step.accounts).map(([name, info]) => (
              <motion.div
                key={name}
                layout
                className={cn(
                  "rounded-lg border px-4 py-3 transition-all",
                  info.balance !== "$0.00"
                    ? info.type === "debit"
                      ? "border-blue-200 bg-blue-50"
                      : "border-emerald-200 bg-emerald-50"
                    : "border-slate-100 bg-slate-50"
                )}
              >
                <div className="flex items-center justify-between">
                  <code className="text-xs font-mono text-slate-700">{name}</code>
                  <motion.span
                    key={info.balance}
                    initial={{ scale: 1.2, color: "#6366F1" }}
                    animate={{ scale: 1, color: info.balance === "$0.00" ? "#94a3b8" : "#0f172a" }}
                    className="text-sm font-bold font-mono"
                  >
                    {info.balance}
                  </motion.span>
                </div>
              </motion.div>
            ))}
          </div>
        </div>

        {/* Invariant */}
        <motion.div
          key={`invariant-${activeStep}`}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.3 }}
          className="rounded-xl bg-slate-900 p-4"
        >
          <div className="flex items-center justify-between">
            <div>
              <span className="text-[10px] uppercase tracking-widest text-emerald-400 font-semibold">
                Invariant Check
              </span>
              <div className="flex items-center gap-2 mt-1">
                <code className="text-xs font-mono text-slate-300">Σ debits</code>
                <Equal size={12} className="text-slate-500" />
                <code className="text-xs font-mono text-slate-300">Σ credits</code>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <code className="text-sm font-mono font-bold text-emerald-400">$50.00 = $50.00</code>
              <span className="text-emerald-400 text-xs">✓ Balanced</span>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
