"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { Search, Filter, Download, Loader2 } from "lucide-react";
import Link from "next/link";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { StatusBadge, FraudBadge } from "@/components/ui/badge";
import { EmptyState } from "@/components/ui/empty-state";
import { formatCurrency, formatDate, truncateId } from "@/lib/utils";
import { useAuth } from "@/lib/auth";
import type { TransactionStatus } from "@/types";

interface ApiTransaction {
  id: string;
  amount: { cents: number; currency: string; formatted: string };
  currency: string;
  status: TransactionStatus;
  fraud_decision: string | null;
  fraud_score: string | null;
  card_last_four: string | null;
  card_brand: string | null;
  merchant_id: string;
  idempotency_key: string;
  fee_cents: number | null;
  net_cents: number | null;
  created_at: string;
}

interface ApiResponse {
  data: ApiTransaction[];
  meta: { total_count: number; page: number; per_page: number; total_pages: number };
}

const statusFilters: TransactionStatus[] = ["pending", "authorized", "captured", "settled", "failed", "refunded", "blocked"];

export default function TransactionsPage() {
  const { apiFetch } = useAuth();
  const [transactions, setTransactions] = useState<ApiTransaction[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [filter, setFilter] = useState<TransactionStatus | "all">("all");
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);

  const fetchTransactions = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page), per_page: "25" });
      if (filter !== "all") params.set("status", filter);
      const res = await apiFetch<ApiResponse>(`/api/v1/transactions?${params}`);
      setTransactions(res.data);
      setTotalCount(res.meta.total_count);
      setTotalPages(res.meta.total_pages);
    } catch {
      // handled by auth guard
    } finally {
      setLoading(false);
    }
  }, [apiFetch, page, filter]);

  useEffect(() => { fetchTransactions(); }, [fetchTransactions]);

  const filtered = search
    ? transactions.filter((tx) =>
        tx.id.includes(search) || tx.idempotency_key.includes(search)
      )
    : transactions;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Transactions</h1>
          <p className="mt-1 text-sm text-slate-500">{totalCount.toLocaleString()} total transactions</p>
        </div>
        <Button variant="secondary" size="sm">
          <Download size={14} />
          Export
        </Button>
      </div>

      <Card padding="none">
        <div className="flex items-center gap-4 border-b border-slate-100 px-6 py-4">
          <div className="flex items-center gap-2 flex-1">
            <Search size={16} className="text-slate-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search by ID..."
              className="flex-1 bg-transparent text-sm text-slate-900 placeholder:text-slate-400 outline-none"
            />
          </div>
          <div className="flex items-center gap-1">
            <Filter size={14} className="text-slate-400 mr-1" />
            <button
              onClick={() => { setFilter("all"); setPage(1); }}
              className={`rounded-md px-2.5 py-1 text-xs font-medium transition-colors ${
                filter === "all" ? "bg-indigo-600 text-white" : "text-slate-500 hover:bg-slate-50"
              }`}
            >
              All
            </button>
            {statusFilters.map((s) => (
              <button
                key={s}
                onClick={() => { setFilter(s); setPage(1); }}
                className={`rounded-md px-2.5 py-1 text-xs font-medium capitalize transition-colors ${
                  filter === s ? "bg-indigo-600 text-white" : "text-slate-500 hover:bg-slate-50"
                }`}
              >
                {s}
              </button>
            ))}
          </div>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-20">
            <Loader2 className="h-6 w-6 animate-spin text-indigo-600" />
          </div>
        ) : filtered.length === 0 ? (
          <EmptyState
            title="No transactions found"
            description="Try adjusting your search or filters"
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-slate-100 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                  <th className="px-6 py-3">ID</th>
                  <th className="px-4 py-3">Amount</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Fraud</th>
                  <th className="px-4 py-3">Score</th>
                  <th className="px-4 py-3">Card</th>
                  <th className="px-4 py-3 text-right pr-6">Date</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((tx, i) => (
                  <motion.tr
                    key={tx.id}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: i * 0.02 }}
                    className="border-b border-slate-50 text-sm transition-colors hover:bg-slate-50"
                  >
                    <td className="px-6 py-3">
                      <Link
                        href={`/transactions/${tx.id}`}
                        className="font-mono text-xs text-indigo-600 hover:underline"
                      >
                        {truncateId(tx.id)}
                      </Link>
                    </td>
                    <td className="px-4 py-3 font-medium tabular-nums text-slate-900">
                      {formatCurrency(tx.amount.cents)}
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge status={tx.status} />
                    </td>
                    <td className="px-4 py-3">
                      {tx.fraud_decision && <FraudBadge decision={tx.fraud_decision as "pass" | "review" | "block"} />}
                    </td>
                    <td className="px-4 py-3 tabular-nums text-slate-500 text-xs">
                      {tx.fraud_score ? parseFloat(tx.fraud_score).toFixed(2) : "-"}
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-500">
                      {tx.card_brand && tx.card_last_four ? `${tx.card_brand} ••${tx.card_last_four}` : "-"}
                    </td>
                    <td className="px-4 py-3 text-right pr-6 text-xs text-slate-400">
                      {formatDate(tx.created_at)}
                    </td>
                  </motion.tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between border-t border-slate-100 px-6 py-3">
            <p className="text-xs text-slate-400">
              Page {page} of {totalPages}
            </p>
            <div className="flex gap-2">
              <Button
                variant="secondary"
                size="sm"
                disabled={page <= 1}
                onClick={() => setPage(page - 1)}
              >
                Previous
              </Button>
              <Button
                variant="secondary"
                size="sm"
                disabled={page >= totalPages}
                onClick={() => setPage(page + 1)}
              >
                Next
              </Button>
            </div>
          </div>
        )}
      </Card>
    </div>
  );
}
