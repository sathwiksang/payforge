"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { StatusBadge } from "@/components/ui/badge";
import { formatRelativeTime } from "@/lib/utils";
import { useAuth } from "@/lib/auth";
import { Loader2 } from "lucide-react";

interface LiveTransaction {
  id: string;
  status: string;
  amount: { cents: number; currency: string; formatted: string };
  fraud_score: string | null;
  card_brand: string | null;
  created_at: string;
}

const STATUSES = ["captured", "authorized", "settled", "pending", "captured", "captured", "authorized", "settled"];
const CARD_BRANDS = ["visa", "mastercard", "amex", "visa", "visa", "mastercard"];
const AMOUNTS = [
  { min: 500, max: 5000 },
  { min: 5000, max: 25000 },
  { min: 25000, max: 100000 },
  { min: 1000, max: 15000 },
];

function generateTransaction(): LiveTransaction {
  const cents = Math.floor(
    Math.random() * (AMOUNTS[Math.floor(Math.random() * AMOUNTS.length)].max -
      AMOUNTS[Math.floor(Math.random() * AMOUNTS.length)].min) +
    AMOUNTS[Math.floor(Math.random() * AMOUNTS.length)].min
  );
  const status = STATUSES[Math.floor(Math.random() * STATUSES.length)];
  const brand = CARD_BRANDS[Math.floor(Math.random() * CARD_BRANDS.length)];
  const score = (Math.random() * 0.35).toFixed(4);

  return {
    id: `live-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    status,
    amount: {
      cents,
      currency: "USD",
      formatted: `$${(cents / 100).toFixed(2)}`,
    },
    fraud_score: score,
    card_brand: brand,
    created_at: new Date().toISOString(),
  };
}

export function LiveFeed() {
  const { apiFetch } = useAuth();
  const [transactions, setTransactions] = useState<LiveTransaction[]>([]);
  const [loading, setLoading] = useState(true);
  const hasFetched = useRef(false);

  // Fetch real transactions once on mount
  const fetchTransactions = useCallback(async () => {
    if (hasFetched.current) return;
    hasFetched.current = true;
    try {
      const res = await apiFetch<{ data: LiveTransaction[] }>(
        "/api/v1/transactions?per_page=10"
      );
      setTransactions(res.data);
    } catch {
      // start with empty if API fails
    } finally {
      setLoading(false);
    }
  }, [apiFetch]);

  useEffect(() => {
    fetchTransactions();
  }, [fetchTransactions]);

  // Simulate live transactions arriving
  useEffect(() => {
    if (loading) return;

    // Add first simulated one after a short delay
    const initialTimeout = setTimeout(() => {
      setTransactions((prev) => [generateTransaction(), ...prev].slice(0, 20));
    }, 2000);

    // Then add new ones every 3-6 seconds
    const interval = setInterval(() => {
      setTransactions((prev) => [generateTransaction(), ...prev].slice(0, 20));
    }, 3000 + Math.random() * 3000);

    return () => {
      clearTimeout(initialTimeout);
      clearInterval(interval);
    };
  }, [loading]);

  return (
    <Card padding="none">
      <CardHeader className="px-6 pt-6 pb-4">
        <CardTitle>Live Transactions</CardTitle>
        <div className="flex items-center gap-1.5">
          <span className="relative flex h-2.5 w-2.5">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
            <span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-emerald-500" />
          </span>
          <span className="text-xs font-medium text-emerald-600">LIVE</span>
        </div>
      </CardHeader>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-5 w-5 animate-spin text-indigo-600" />
        </div>
      ) : transactions.length === 0 ? (
        <p className="px-6 py-8 text-sm text-slate-400 text-center">No transactions yet</p>
      ) : (
        <div className="max-h-96 overflow-y-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-100 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                <th className="px-6 py-2.5">Amount</th>
                <th className="px-3 py-2.5">Status</th>
                <th className="px-3 py-2.5">Score</th>
                <th className="px-3 py-2.5">Card</th>
                <th className="px-3 py-2.5 text-right pr-6">Time</th>
              </tr>
            </thead>
            <tbody>
              <AnimatePresence mode="popLayout" initial={false}>
                {transactions.map((tx) => (
                  <motion.tr
                    key={tx.id}
                    layout
                    initial={{ opacity: 0, y: -20, backgroundColor: "rgba(99, 102, 241, 0.08)" }}
                    animate={{ opacity: 1, y: 0, backgroundColor: "rgba(255, 255, 255, 1)" }}
                    exit={{ opacity: 0, height: 0 }}
                    transition={{ duration: 0.4 }}
                    className="border-b border-slate-50 text-sm"
                  >
                    <td className="px-6 py-2.5 font-medium tabular-nums text-slate-900">
                      {tx.amount.formatted}
                    </td>
                    <td className="px-3 py-2.5">
                      <StatusBadge status={tx.status as "captured" | "authorized" | "failed" | "refunded" | "pending" | "blocked" | "settled" | "voided"} />
                    </td>
                    <td className="px-3 py-2.5 tabular-nums text-slate-500">
                      {tx.fraud_score ? parseFloat(tx.fraud_score).toFixed(2) : "-"}
                    </td>
                    <td className="px-3 py-2.5 text-slate-600 capitalize">
                      {tx.card_brand || "-"}
                    </td>
                    <td className="px-3 py-2.5 text-right pr-6 text-xs text-slate-400">
                      {formatRelativeTime(tx.created_at)}
                    </td>
                  </motion.tr>
                ))}
              </AnimatePresence>
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}
