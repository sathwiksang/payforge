"use client";

import { useState, useEffect, useCallback } from "react";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import { useAuth } from "@/lib/auth";
import { Loader2 } from "lucide-react";

const ranges = ["7d", "30d", "90d", "1y"] as const;
type Range = (typeof ranges)[number];

interface VolumeDataPoint {
  date: string;
  volume_cents: number;
  transaction_count: number;
}

function formatYAxis(value: number): string {
  if (value >= 10000000) return `$${(value / 100000).toFixed(0)}k`;
  if (value >= 100000) return `$${(value / 100).toFixed(0)}`;
  if (value >= 1000) return `$${(value / 100).toFixed(0)}`;
  return `$${(value / 100).toFixed(2)}`;
}

function formatDateLabel(dateStr: string): string {
  const d = new Date(dateStr + "T00:00:00");
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

export function VolumeChart() {
  const { apiFetch } = useAuth();
  const [range, setRange] = useState<Range>("30d");
  const [data, setData] = useState<VolumeDataPoint[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchVolume = useCallback(async () => {
    setLoading(true);
    try {
      const res = await apiFetch<{ data: VolumeDataPoint[] }>(
        `/api/v1/merchants/me/analytics/volume?range=${range}`
      );
      setData(res.data);
    } catch {
      // handled
    } finally {
      setLoading(false);
    }
  }, [apiFetch, range]);

  useEffect(() => { fetchVolume(); }, [fetchVolume]);

  const chartData = data.map((d) => ({
    date: formatDateLabel(d.date),
    volume: d.volume_cents,
    transactions: d.transaction_count,
  }));

  return (
    <Card>
      <CardHeader>
        <CardTitle>Transaction Volume</CardTitle>
        <div className="flex gap-1 rounded-lg border border-slate-200 p-0.5">
          {ranges.map((r) => (
            <button
              key={r}
              onClick={() => setRange(r)}
              className={cn(
                "rounded-md px-2.5 py-1 text-xs font-medium transition-colors",
                range === r
                  ? "bg-indigo-600 text-white"
                  : "text-slate-500 hover:text-slate-700"
              )}
            >
              {r}
            </button>
          ))}
        </div>
      </CardHeader>

      <div className="mt-4 h-72">
        {loading ? (
          <div className="flex h-full items-center justify-center">
            <Loader2 className="h-5 w-5 animate-spin text-indigo-600" />
          </div>
        ) : chartData.length === 0 ? (
          <div className="flex h-full items-center justify-center">
            <p className="text-sm text-slate-400">No transaction data for this period</p>
          </div>
        ) : (
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={chartData} margin={{ top: 5, right: 5, bottom: 5, left: 5 }}>
              <defs>
                <linearGradient id="volumeGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#6366F1" stopOpacity={0.15} />
                  <stop offset="100%" stopColor="#6366F1" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#F1F5F9" vertical={false} />
              <XAxis
                dataKey="date"
                tick={{ fontSize: 11, fill: "#94A3B8" }}
                tickLine={false}
                axisLine={false}
                interval={Math.max(0, Math.floor(chartData.length / 6))}
              />
              <YAxis
                tickFormatter={formatYAxis}
                tick={{ fontSize: 11, fill: "#94A3B8" }}
                tickLine={false}
                axisLine={false}
                width={50}
              />
              <Tooltip
                contentStyle={{
                  borderRadius: 8,
                  border: "1px solid #E2E8F0",
                  boxShadow: "0 4px 6px -1px rgba(0,0,0,0.07)",
                  fontSize: 13,
                }}
                formatter={(value) => [
                  `$${(Number(value) / 100).toLocaleString(undefined, { minimumFractionDigits: 2 })}`,
                  "Volume",
                ]}
              />
              <Area
                type="monotone"
                dataKey="volume"
                stroke="#6366F1"
                strokeWidth={2}
                fill="url(#volumeGradient)"
              />
            </AreaChart>
          </ResponsiveContainer>
        )}
      </div>
    </Card>
  );
}
