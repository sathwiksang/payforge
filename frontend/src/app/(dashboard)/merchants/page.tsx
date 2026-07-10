"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { Loader2 } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { formatDate } from "@/lib/utils";
import { useAuth } from "@/lib/auth";

interface ApiMerchant {
  id: string;
  name: string;
  status: string;
  risk_tier: string;
  fee_percentage: string;
  fee_fixed_cents: number;
  onboarded_at: string | null;
  created_at: string;
  transaction_count?: number;
  email?: string;
  webhook_url?: string;
}

const statusColors: Record<string, string> = {
  active: "bg-emerald-50 text-emerald-700",
  suspended: "bg-red-50 text-red-700",
  deactivated: "bg-slate-100 text-slate-600",
};

const riskColors: Record<string, string> = {
  standard: "bg-slate-100 text-slate-600",
  elevated: "bg-amber-50 text-amber-700",
  high: "bg-red-50 text-red-700",
};

export default function MerchantsPage() {
  const { apiFetch, user } = useAuth();
  const [merchant, setMerchant] = useState<ApiMerchant | null>(null);
  const [analytics, setAnalytics] = useState<{ analytics: { total_volume_cents: number; total_revenue_cents: number; transaction_count: number; fraud_rate: number; avg_transaction_cents: number } } | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [me, analyticsRes] = await Promise.all([
        apiFetch<{ data: ApiMerchant }>("/api/v1/merchants/me"),
        apiFetch<{ data: ApiMerchant & { analytics: { total_volume_cents: number; total_revenue_cents: number; transaction_count: number; fraud_rate: number; avg_transaction_cents: number } } }>("/api/v1/merchants/me/analytics"),
      ]);
      setMerchant(me.data);
      setAnalytics(analyticsRes.data);
    } catch {
      // handled
    } finally {
      setLoading(false);
    }
  }, [apiFetch]);

  useEffect(() => { fetchData(); }, [fetchData]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="h-6 w-6 animate-spin text-indigo-600" />
      </div>
    );
  }

  if (!merchant) return null;

  const a = analytics?.analytics;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Merchant Profile</h1>
        <p className="mt-1 text-sm text-slate-500">Your merchant account details</p>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {a && (
          <>
            <Card>
              <p className="text-xs font-medium text-slate-400 uppercase">Total Volume</p>
              <p className="mt-1 text-2xl font-bold text-slate-900 tabular-nums">
                ${(a.total_volume_cents / 100).toLocaleString(undefined, { minimumFractionDigits: 2 })}
              </p>
            </Card>
            <Card>
              <p className="text-xs font-medium text-slate-400 uppercase">Revenue</p>
              <p className="mt-1 text-2xl font-bold text-slate-900 tabular-nums">
                ${(a.total_revenue_cents / 100).toLocaleString(undefined, { minimumFractionDigits: 2 })}
              </p>
            </Card>
            <Card>
              <p className="text-xs font-medium text-slate-400 uppercase">Transactions</p>
              <p className="mt-1 text-2xl font-bold text-slate-900 tabular-nums">
                {a.transaction_count.toLocaleString()}
              </p>
            </Card>
            <Card>
              <p className="text-xs font-medium text-slate-400 uppercase">Fraud Rate</p>
              <p className="mt-1 text-2xl font-bold text-slate-900 tabular-nums">
                {(a.fraud_rate * 100).toFixed(2)}%
              </p>
            </Card>
          </>
        )}
      </div>

      <Card padding="none">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-100 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                <th className="px-6 py-3">Merchant</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Risk Tier</th>
                <th className="px-4 py-3">Fee</th>
                <th className="px-4 py-3">Transactions</th>
                <th className="px-4 py-3 text-right pr-6">Onboarded</th>
              </tr>
            </thead>
            <tbody>
              <motion.tr
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="border-b border-slate-50 text-sm"
              >
                <td className="px-6 py-3">
                  <div>
                    <p className="font-medium text-slate-900">{merchant.name}</p>
                    {merchant.email && <p className="text-xs text-slate-400">{merchant.email}</p>}
                  </div>
                </td>
                <td className="px-4 py-3">
                  <Badge className={statusColors[merchant.status] || "bg-slate-100 text-slate-600"}>{merchant.status}</Badge>
                </td>
                <td className="px-4 py-3">
                  <Badge className={riskColors[merchant.risk_tier] || "bg-slate-100 text-slate-600"}>{merchant.risk_tier}</Badge>
                </td>
                <td className="px-4 py-3 text-slate-600 tabular-nums">
                  {merchant.fee_percentage}% + ${(merchant.fee_fixed_cents / 100).toFixed(2)}
                </td>
                <td className="px-4 py-3 text-slate-600 tabular-nums">
                  {(merchant.transaction_count || a?.transaction_count || 0).toLocaleString()}
                </td>
                <td className="px-4 py-3 text-right pr-6 text-xs text-slate-400">
                  {merchant.onboarded_at ? formatDate(merchant.onboarded_at) : "-"}
                </td>
              </motion.tr>
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}
