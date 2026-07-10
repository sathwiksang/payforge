"use client";

import { use, useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { ArrowLeft, Loader2 } from "lucide-react";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge, PriorityBadge, FraudBadge } from "@/components/ui/badge";
import { formatCurrency, formatDate, truncateId } from "@/lib/utils";
import { useAuth } from "@/lib/auth";

interface ApiFraudCaseDetail {
  id: string;
  transaction_id: string;
  merchant_id: string;
  status: string;
  priority: string;
  risk_score: string;
  decision: string;
  model_used: string;
  reviewer_id: string | null;
  notes: string | null;
  reviewed_at: string | null;
  resolved_at: string | null;
  created_at: string;
  transaction?: {
    id: string;
    amount: { cents: number; currency: string; formatted: string };
    status: string;
    card_last_four: string | null;
    card_brand: string | null;
    created_at: string;
  };
}

const caseStatusConfig: Record<string, { label: string; className: string }> = {
  open: { label: "Open", className: "bg-amber-50 text-amber-700" },
  under_review: { label: "Under Review", className: "bg-blue-50 text-blue-700" },
  confirmed_fraud: { label: "Confirmed Fraud", className: "bg-red-50 text-red-700" },
  false_positive: { label: "False Positive", className: "bg-emerald-50 text-emerald-700" },
  escalated: { label: "Escalated", className: "bg-purple-50 text-purple-700" },
};

export default function FraudCaseDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { apiFetch } = useAuth();
  const [fc, setFc] = useState<ApiFraudCaseDetail | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const res = await apiFetch<{ data: ApiFraudCaseDetail }>(`/api/v1/fraud/cases/${id}`);
      setFc(res.data);
    } catch {
      // handled
    } finally {
      setLoading(false);
    }
  }, [apiFetch, id]);

  useEffect(() => { fetchData(); }, [fetchData]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="h-6 w-6 animate-spin text-indigo-600" />
      </div>
    );
  }

  if (!fc) return null;

  const score = parseFloat(fc.risk_score);
  const statusCfg = caseStatusConfig[fc.status] || { label: fc.status, className: "bg-slate-100 text-slate-600" };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Link href="/fraud-cases">
          <Button variant="ghost" size="sm">
            <ArrowLeft size={16} />
            Back
          </Button>
        </Link>
        <div className="flex-1">
          <div className="flex items-center gap-3">
            <h1 className="text-xl font-bold text-slate-900 font-mono">{truncateId(id, 12)}</h1>
            <Badge className={statusCfg.className}>{statusCfg.label}</Badge>
            <PriorityBadge priority={fc.priority as "low" | "medium" | "high" | "critical"} />
            <FraudBadge decision={fc.decision as "pass" | "review" | "block"} />
          </div>
          <p className="mt-1 text-sm text-slate-500">
            Created {formatDate(fc.created_at)} &middot; Model: {fc.model_used}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card>
          <CardTitle>Case Details</CardTitle>
          <dl className="mt-4 space-y-3">
            {[
              ["Risk Score", (score * 100).toFixed(1) + "%"],
              ["Decision", fc.decision],
              ["Model", fc.model_used],
              ["Status", statusCfg.label],
              ["Priority", fc.priority],
              ["Transaction", truncateId(fc.transaction_id)],
              ["Created", formatDate(fc.created_at)],
              ...(fc.reviewed_at ? [["Reviewed", formatDate(fc.reviewed_at)]] : []),
              ...(fc.notes ? [["Notes", fc.notes]] : []),
            ].map(([label, value]) => (
              <div key={label} className="flex items-center justify-between text-sm">
                <dt className="text-slate-500">{label}</dt>
                <dd className="font-medium text-slate-900 text-xs font-mono">{value}</dd>
              </div>
            ))}
          </dl>
        </Card>

        <Card>
          <CardTitle>Risk Score</CardTitle>
          <div className="mt-4 text-center py-6">
            <div className={`inline-flex h-20 w-20 items-center justify-center rounded-full text-2xl font-bold ${
              score >= 0.85 ? "bg-red-100 text-red-700" :
              score >= 0.6 ? "bg-amber-100 text-amber-700" :
              "bg-emerald-100 text-emerald-700"
            }`}>
              {(score * 100).toFixed(0)}
            </div>
            <p className="mt-3 text-sm text-slate-500">
              {score >= 0.85 ? "High Risk - Blocked" :
               score >= 0.6 ? "Medium Risk - Under Review" :
               "Low Risk"}
            </p>
            <p className="text-xs text-slate-400 mt-1">
              Scored by {fc.model_used}
            </p>
          </div>
        </Card>
      </div>

      {fc.transaction && (
        <Card>
          <CardTitle>Associated Transaction</CardTitle>
          <dl className="mt-4 space-y-3">
            {[
              ["Transaction ID", truncateId(fc.transaction.id)],
              ["Amount", fc.transaction.amount.formatted],
              ["Status", fc.transaction.status],
              ["Card", fc.transaction.card_last_four ? `\u2022\u2022\u2022\u2022 ${fc.transaction.card_last_four}` : "-"],
              ["Created", formatDate(fc.transaction.created_at)],
            ].map(([label, value]) => (
              <div key={label} className="flex items-center justify-between text-sm">
                <dt className="text-slate-500">{label}</dt>
                <dd className="font-medium text-slate-900 text-xs font-mono">{value}</dd>
              </div>
            ))}
          </dl>
          <div className="mt-4">
            <Link href={`/transactions/${fc.transaction.id}`}>
              <Button variant="secondary" size="sm">View Transaction</Button>
            </Link>
          </div>
        </Card>
      )}
    </div>
  );
}
