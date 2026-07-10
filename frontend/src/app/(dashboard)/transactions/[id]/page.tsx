"use client";

import { use, useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { ArrowLeft, Loader2 } from "lucide-react";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { StatusBadge, FraudBadge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { LifecycleTimeline } from "@/components/transactions/lifecycle-timeline";
import dynamic from "next/dynamic";
import { formatCurrency, formatDate } from "@/lib/utils";
import { useAuth } from "@/lib/auth";

const ShapWaterfall = dynamic(
  () => import("@/components/fraud/shap-waterfall").then((m) => m.ShapWaterfall),
  { ssr: false }
);

interface ApiTxDetail {
  id: string;
  amount: { cents: number; currency: string; formatted: string };
  currency: string;
  status: string;
  fraud_decision: string | null;
  fraud_score: string | null;
  card_last_four: string | null;
  card_brand: string | null;
  merchant_id: string;
  idempotency_key: string;
  fee_cents: number | null;
  net_cents: number | null;
  authorized_at: string | null;
  captured_at: string | null;
  settled_at: string | null;
  refunded_at: string | null;
  failed_at: string | null;
  created_at: string;
}

interface EventData {
  type: string;
  data: Record<string, unknown>;
  timestamp: string | null;
}

interface LedgerData {
  id: string;
  debit_account: string;
  credit_account: string;
  amount_cents: number;
  currency: string;
  entry_type: string;
  created_at: string;
}

export default function TransactionDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { apiFetch } = useAuth();
  const [tx, setTx] = useState<ApiTxDetail | null>(null);
  const [events, setEvents] = useState<EventData[]>([]);
  const [ledger, setLedger] = useState<LedgerData[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [txRes, eventsRes, ledgerRes] = await Promise.all([
        apiFetch<{ data: ApiTxDetail }>(`/api/v1/transactions/${id}`),
        apiFetch<{ data: EventData[] }>(`/api/v1/transactions/${id}/events`),
        apiFetch<{ data: LedgerData[] }>(`/api/v1/transactions/${id}/ledger`),
      ]);
      setTx(txRes.data);
      setEvents(eventsRes.data);
      setLedger(ledgerRes.data);
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

  if (!tx) return null;

  const timelineSteps = [
    { label: "Initiated", time: formatDate(tx.created_at), status: "completed" as const },
    { label: "Authorized", time: tx.authorized_at ? formatDate(tx.authorized_at) : "-", status: tx.authorized_at ? "completed" as const : "pending" as const },
    { label: "Fraud Check", time: tx.fraud_decision ? `${tx.fraud_decision} (${tx.fraud_score})` : "-", status: tx.fraud_decision ? "completed" as const : "pending" as const },
    { label: "Captured", time: tx.captured_at ? formatDate(tx.captured_at) : "-", status: tx.captured_at ? "completed" as const : "pending" as const },
    { label: "Settled", time: tx.settled_at ? formatDate(tx.settled_at) : "Pending", status: tx.settled_at ? "completed" as const : "pending" as const },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Link href="/transactions">
          <Button variant="ghost" size="sm">
            <ArrowLeft size={16} />
            Back
          </Button>
        </Link>
        <div className="flex-1">
          <div className="flex items-center gap-3">
            <h1 className="text-xl font-bold text-slate-900 font-mono">{id.slice(0, 12)}...</h1>
            <StatusBadge status={tx.status as "captured" | "authorized" | "failed" | "refunded" | "pending" | "blocked" | "settled" | "voided"} />
            {tx.fraud_decision && <FraudBadge decision={tx.fraud_decision as "pass" | "review" | "block"} />}
          </div>
        </div>
        {tx.status === "captured" && (
          <Button variant="secondary" size="sm">Refund</Button>
        )}
        {tx.status === "authorized" && (
          <Button variant="secondary" size="sm">Void</Button>
        )}
      </div>

      <Card>
        <CardTitle>Transaction Lifecycle</CardTitle>
        <div className="mt-6">
          <LifecycleTimeline steps={timelineSteps} />
        </div>
      </Card>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card>
          <CardTitle>Transaction Details</CardTitle>
          <dl className="mt-4 space-y-3">
            {[
              ["Amount", tx.amount.formatted],
              ["Currency", tx.currency],
              ["Status", tx.status],
              ["Card", tx.card_last_four ? `\u2022\u2022\u2022\u2022 ${tx.card_last_four} (${tx.card_brand || "Unknown"})` : "-"],
              ["Fee", tx.fee_cents != null ? formatCurrency(tx.fee_cents) : "-"],
              ["Net", tx.net_cents != null ? formatCurrency(tx.net_cents) : "-"],
              ["Fraud Score", tx.fraud_score || "-"],
              ["Created", formatDate(tx.created_at)],
            ].map(([label, value]) => (
              <div key={label} className="flex items-center justify-between text-sm">
                <dt className="text-slate-500">{label}</dt>
                <dd className="font-medium text-slate-900 font-mono text-xs">{value}</dd>
              </div>
            ))}
          </dl>
        </Card>

        <Card>
          <CardTitle>Risk Analysis</CardTitle>
          <div className="mt-4">
            {tx.fraud_score ? (
              <div className="text-center py-6">
                <div className={`inline-flex h-16 w-16 items-center justify-center rounded-full text-lg font-bold ${
                  parseFloat(tx.fraud_score) >= 0.85 ? "bg-red-100 text-red-700" :
                  parseFloat(tx.fraud_score) >= 0.6 ? "bg-amber-100 text-amber-700" :
                  "bg-emerald-100 text-emerald-700"
                }`}>
                  {(parseFloat(tx.fraud_score) * 100).toFixed(0)}
                </div>
                <p className="mt-2 text-sm text-slate-500">Risk Score</p>
                <p className="text-xs text-slate-400 mt-1">Decision: {tx.fraud_decision || "N/A"}</p>
              </div>
            ) : (
              <p className="text-sm text-slate-400 text-center py-6">No fraud scoring data</p>
            )}
          </div>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card padding="none">
          <CardHeader className="px-6 pt-6 pb-3">
            <CardTitle>Event Stream ({events.length})</CardTitle>
          </CardHeader>
          {events.length > 0 ? (
            <div className="divide-y divide-slate-50">
              {events.map((evt, i) => (
                <div key={i} className="flex items-center gap-4 px-6 py-2.5 text-sm">
                  <span className="font-medium text-slate-700">{evt.type.split("::").pop()}</span>
                  <span className="text-slate-500 text-xs ml-auto">
                    {evt.timestamp ? formatDate(evt.timestamp) : ""}
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <p className="px-6 py-6 text-sm text-slate-400">No events recorded</p>
          )}
        </Card>

        <Card padding="none">
          <CardHeader className="px-6 pt-6 pb-3">
            <CardTitle>Ledger Entries ({ledger.length})</CardTitle>
          </CardHeader>
          {ledger.length > 0 ? (
            <div className="divide-y divide-slate-50">
              {ledger.map((entry) => (
                <div key={entry.id} className="flex items-center gap-4 px-6 py-2.5 text-sm">
                  <span className="text-slate-600">{entry.entry_type}</span>
                  <span className="ml-auto font-mono text-xs font-medium text-slate-900 tabular-nums">
                    {formatCurrency(entry.amount_cents)}
                  </span>
                  <span className="text-xs text-slate-400">{entry.currency}</span>
                </div>
              ))}
            </div>
          ) : (
            <p className="px-6 py-6 text-sm text-slate-400">No ledger entries</p>
          )}
        </Card>
      </div>
    </div>
  );
}
