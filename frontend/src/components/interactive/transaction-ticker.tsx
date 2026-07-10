"use client";

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { CheckCircle, Shield, Clock, CreditCard } from "lucide-react";

interface TickerTransaction {
  id: string;
  amount: string;
  status: "captured" | "authorized" | "settled" | "pending";
  card: string;
  score: string;
  merchant: string;
}

const MERCHANTS = ["CoffeeChain Co", "TechGadgets Pro", "BookWorm Digital", "CloudSync Inc", "FreshMart", "UrbanStyle"];
const CARDS = ["Visa •••• 4242", "MC •••• 5556", "Amex •••• 0005", "Visa •••• 1234", "MC •••• 8910"];

const STATUS_CONFIG = {
  captured: { icon: CheckCircle, label: "Captured", color: "text-emerald-500", bg: "bg-emerald-50" },
  authorized: { icon: Shield, label: "Authorized", color: "text-blue-500", bg: "bg-blue-50" },
  settled: { icon: CheckCircle, label: "Settled", color: "text-emerald-600", bg: "bg-emerald-50" },
  pending: { icon: Clock, label: "Pending", color: "text-slate-500", bg: "bg-slate-50" },
};

function generateTx(): TickerTransaction {
  const statuses: TickerTransaction["status"][] = ["captured", "authorized", "settled", "captured", "captured", "authorized"];
  const cents = Math.floor(Math.random() * 95000) + 500;
  return {
    id: `tx-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
    amount: `$${(cents / 100).toFixed(2)}`,
    status: statuses[Math.floor(Math.random() * statuses.length)],
    card: CARDS[Math.floor(Math.random() * CARDS.length)],
    score: (Math.random() * 0.3).toFixed(2),
    merchant: MERCHANTS[Math.floor(Math.random() * MERCHANTS.length)],
  };
}

export function TransactionTicker() {
  const [transactions, setTransactions] = useState<TickerTransaction[]>([]);

  useEffect(() => {
    // Seed initial batch
    setTransactions(Array.from({ length: 5 }, generateTx));

    const interval = setInterval(() => {
      setTransactions((prev) => [generateTx(), ...prev].slice(0, 8));
    }, 2500 + Math.random() * 1500);

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="rounded-2xl border border-slate-200 bg-white shadow-xl overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between px-5 py-3 bg-slate-50 border-b border-slate-200">
        <div className="flex items-center gap-2">
          <CreditCard size={14} className="text-indigo-600" />
          <span className="text-xs font-bold text-slate-900">Live Transactions</span>
        </div>
        <div className="flex items-center gap-1.5">
          <span className="relative flex h-2 w-2">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-500" />
          </span>
          <span className="text-[10px] font-semibold text-emerald-600 uppercase tracking-wider">Live</span>
        </div>
      </div>

      {/* Transaction rows */}
      <div className="max-h-[280px] overflow-hidden">
        <AnimatePresence mode="popLayout" initial={false}>
          {transactions.map((tx) => {
            const cfg = STATUS_CONFIG[tx.status];
            const Icon = cfg.icon;
            return (
              <motion.div
                key={tx.id}
                layout
                initial={{ opacity: 0, y: -30, backgroundColor: "rgba(99, 102, 241, 0.06)" }}
                animate={{ opacity: 1, y: 0, backgroundColor: "rgba(255, 255, 255, 1)" }}
                exit={{ opacity: 0, height: 0 }}
                transition={{ type: "spring", stiffness: 400, damping: 30 }}
                className="flex items-center justify-between px-5 py-2.5 border-b border-slate-50"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <div className={`flex h-7 w-7 items-center justify-center rounded-lg ${cfg.bg}`}>
                    <Icon size={13} className={cfg.color} />
                  </div>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-semibold text-slate-900 tabular-nums">{tx.amount}</span>
                      <span className={`text-[10px] font-medium ${cfg.color} uppercase`}>{cfg.label}</span>
                    </div>
                    <div className="text-[11px] text-slate-400 truncate">{tx.merchant} · {tx.card}</div>
                  </div>
                </div>
                <div className="text-right flex-shrink-0 ml-3">
                  <div className="text-[10px] font-mono text-slate-400">
                    risk <span className={parseFloat(tx.score) > 0.15 ? "text-amber-500" : "text-emerald-500"}>{tx.score}</span>
                  </div>
                  <div className="text-[10px] text-slate-300">just now</div>
                </div>
              </motion.div>
            );
          })}
        </AnimatePresence>
      </div>
    </div>
  );
}
