"use client";

import { useState, useEffect, useCallback } from "react";
import dynamic from "next/dynamic";
import { Loader2 } from "lucide-react";
import { MetricCard } from "@/components/dashboard/metric-card";
import { RecentActivity } from "@/components/dashboard/recent-activity";
import { formatCurrency, formatPercent } from "@/lib/utils";
import { useAuth } from "@/lib/auth";

function ChartSkeleton() {
  return (
    <div className="h-64 animate-pulse rounded-xl bg-slate-100" />
  );
}

const VolumeChart = dynamic(
  () => import("@/components/dashboard/volume-chart").then((m) => m.VolumeChart),
  { loading: () => <ChartSkeleton />, ssr: false }
);

const FraudDistribution = dynamic(
  () => import("@/components/dashboard/fraud-distribution").then((m) => m.FraudDistribution),
  { loading: () => <ChartSkeleton />, ssr: false }
);

const PaymentMethodsChart = dynamic(
  () => import("@/components/dashboard/payment-methods-chart").then((m) => m.PaymentMethodsChart),
  { loading: () => <ChartSkeleton />, ssr: false }
);

const LiveFeed = dynamic(
  () => import("@/components/dashboard/live-feed").then((m) => m.LiveFeed),
  { loading: () => <ChartSkeleton />, ssr: false }
);

interface AnalyticsData {
  total_volume_cents: number;
  total_revenue_cents: number;
  transaction_count: number;
  fraud_rate: number;
  avg_transaction_cents: number;
}

export default function DashboardPage() {
  const { apiFetch, user } = useAuth();
  const [analytics, setAnalytics] = useState<AnalyticsData | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchAnalytics = useCallback(async () => {
    try {
      const res = await apiFetch<{ data: { analytics: AnalyticsData } }>("/api/v1/merchants/me/analytics");
      setAnalytics(res.data.analytics);
    } catch {
      // handled
    } finally {
      setLoading(false);
    }
  }, [apiFetch]);

  useEffect(() => { fetchAnalytics(); }, [fetchAnalytics]);

  const greeting = getGreeting();

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="h-6 w-6 animate-spin text-indigo-600" />
      </div>
    );
  }

  const metrics = analytics ? [
    {
      title: "Total Volume",
      value: analytics.total_volume_cents,
      format: (n: number) => formatCurrency(n),
      sparkline: [18, 22, 19, 25, 28, 24, 31, 29, 33, 35, 32, 38],
    },
    {
      title: "Revenue",
      value: analytics.total_revenue_cents,
      format: (n: number) => formatCurrency(n),
      sparkline: [5, 6, 5.5, 7, 6.8, 7.2, 8, 7.5, 8.2, 8.5, 8, 9],
    },
    {
      title: "Transactions",
      value: analytics.transaction_count,
      format: (n: number) => n.toLocaleString(),
      sparkline: [52, 49, 51, 48, 50, 47, 49, 46, 48, 47, 45, 47],
    },
    {
      title: "Fraud Rate",
      value: analytics.fraud_rate,
      format: (n: number) => formatPercent(n),
      sparkline: [0.18, 0.15, 0.16, 0.14, 0.13, 0.15, 0.12, 0.13, 0.11, 0.12, 0.11, 0.12],
    },
  ] : [];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">{greeting}</h1>
          <p className="mt-1 text-sm text-slate-500">
            {new Date().toLocaleDateString("en-US", {
              weekday: "long",
              month: "long",
              day: "numeric",
              year: "numeric",
            })}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {metrics.map((metric, i) => (
          <MetricCard
            key={metric.title}
            title={metric.title}
            value={metric.value}
            format={metric.format}
            sparklineData={metric.sparkline}
            delay={i * 0.08}
          />
        ))}
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <VolumeChart />
        </div>
        <RecentActivity />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <FraudDistribution />
        <PaymentMethodsChart />
        <LiveFeed />
      </div>
    </div>
  );
}

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 12) return "Good morning";
  if (hour < 17) return "Good afternoon";
  return "Good evening";
}
