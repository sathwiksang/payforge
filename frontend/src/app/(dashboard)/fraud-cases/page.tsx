"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { ShieldAlert, Loader2 } from "lucide-react";
import Link from "next/link";
import { Card } from "@/components/ui/card";
import { PriorityBadge, FraudBadge } from "@/components/ui/badge";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { formatDate, truncateId } from "@/lib/utils";
import { useAuth } from "@/lib/auth";
import { cn } from "@/lib/utils";
import type { FraudCaseStatus } from "@/types";

interface ApiFraudCase {
  id: string;
  transaction_id: string;
  merchant_id: string;
  status: string;
  priority: string;
  risk_score: string;
  decision: string;
  model_used: string;
  created_at: string;
}

interface ApiResponse {
  data: ApiFraudCase[];
  meta: { total_count: number; page: number; per_page: number; total_pages: number };
}

const caseStatusConfig: Record<string, { label: string; className: string }> = {
  open: { label: "Open", className: "bg-amber-50 text-amber-700" },
  under_review: { label: "Under Review", className: "bg-blue-50 text-blue-700" },
  confirmed_fraud: { label: "Confirmed", className: "bg-red-50 text-red-700" },
  false_positive: { label: "False Positive", className: "bg-emerald-50 text-emerald-700" },
  escalated: { label: "Escalated", className: "bg-purple-50 text-purple-700" },
};

export default function FraudCasesPage() {
  const { apiFetch } = useAuth();
  const [cases, setCases] = useState<ApiFraudCase[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [statusFilter, setStatusFilter] = useState<FraudCaseStatus | "all">("all");
  const [loading, setLoading] = useState(true);

  const fetchCases = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page), per_page: "20" });
      if (statusFilter !== "all") params.set("status", statusFilter);
      const res = await apiFetch<ApiResponse>(`/api/v1/fraud/cases?${params}`);
      setCases(res.data);
      setTotalCount(res.meta.total_count);
      setTotalPages(res.meta.total_pages);
    } catch {
      // handled by auth
    } finally {
      setLoading(false);
    }
  }, [apiFetch, page, statusFilter]);

  useEffect(() => { fetchCases(); }, [fetchCases]);

  const openCount = cases.filter((c) => c.status === "open").length;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Fraud Cases</h1>
          <p className="mt-1 text-sm text-slate-500">
            {totalCount} total cases{openCount > 0 && ` \u00b7 ${openCount} open on this page`}
          </p>
        </div>
      </div>

      <div className="flex gap-2">
        {["all", "open", "under_review", "escalated", "confirmed_fraud", "false_positive"].map((s) => (
          <button
            key={s}
            onClick={() => { setStatusFilter(s as FraudCaseStatus | "all"); setPage(1); }}
            className={cn(
              "rounded-lg px-3 py-1.5 text-sm font-medium transition-colors",
              statusFilter === s
                ? "bg-indigo-600 text-white"
                : "bg-white border border-slate-200 text-slate-600 hover:bg-slate-50"
            )}
          >
            {s === "all" ? "All" : caseStatusConfig[s]?.label || s}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-20">
          <Loader2 className="h-6 w-6 animate-spin text-indigo-600" />
        </div>
      ) : (
        <div className="space-y-3">
          {cases.length === 0 ? (
            <Card>
              <EmptyState
                icon={<ShieldAlert size={32} />}
                title="No fraud cases"
                description="No cases match the current filter"
              />
            </Card>
          ) : (
            cases.map((fc, i) => {
              const score = parseFloat(fc.risk_score);
              const statusCfg = caseStatusConfig[fc.status] || { label: fc.status, className: "bg-slate-50 text-slate-700" };
              return (
                <motion.div
                  key={fc.id}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.03 }}
                >
                  <Link href={`/fraud-cases/${fc.id}`}>
                    <Card className="transition-shadow hover:shadow-md cursor-pointer">
                      <div className="flex items-center gap-4">
                        <div
                          className={cn(
                            "flex h-12 w-12 items-center justify-center rounded-lg text-sm font-bold",
                            score >= 0.9 ? "bg-red-100 text-red-700" :
                            score >= 0.7 ? "bg-amber-100 text-amber-700" :
                            "bg-emerald-100 text-emerald-700"
                          )}
                        >
                          {(score * 100).toFixed(0)}
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2">
                            <span className="font-mono text-sm font-medium text-slate-900">
                              {truncateId(fc.id)}
                            </span>
                            <Badge className={statusCfg.className}>{statusCfg.label}</Badge>
                            <PriorityBadge priority={fc.priority as "low" | "medium" | "high" | "critical"} />
                            <FraudBadge decision={fc.decision as "pass" | "review" | "block"} />
                          </div>
                          <p className="mt-1 text-xs text-slate-500">
                            Transaction {truncateId(fc.transaction_id)} &middot; {fc.model_used}
                          </p>
                        </div>
                        <span className="text-xs text-slate-400 whitespace-nowrap">
                          {formatDate(fc.created_at)}
                        </span>
                      </div>
                    </Card>
                  </Link>
                </motion.div>
              );
            })
          )}
        </div>
      )}

      {totalPages > 1 && (
        <div className="flex items-center justify-between">
          <p className="text-xs text-slate-400">Page {page} of {totalPages}</p>
          <div className="flex gap-2">
            <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>Previous</Button>
            <Button variant="secondary" size="sm" disabled={page >= totalPages} onClick={() => setPage(page + 1)}>Next</Button>
          </div>
        </div>
      )}
    </div>
  );
}
