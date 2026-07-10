"use client";

import { useState, useEffect, useCallback } from "react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  Cell,
} from "recharts";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { useAuth } from "@/lib/auth";
import { Loader2 } from "lucide-react";

interface FraudDistPoint {
  range: string;
  count: number;
}

const COLORS: Record<string, string> = {
  "0.0-0.1": "#10B981",
  "0.1-0.2": "#10B981",
  "0.2-0.3": "#34D399",
  "0.3-0.4": "#FBBF24",
  "0.4-0.5": "#FBBF24",
  "0.5-0.6": "#F59E0B",
  "0.6-0.7": "#F97316",
  "0.7-0.8": "#EF4444",
  "0.8-0.9": "#EF4444",
  "0.9-1.0": "#DC2626",
};

export function FraudDistribution() {
  const { apiFetch } = useAuth();
  const [data, setData] = useState<FraudDistPoint[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    try {
      const res = await apiFetch<{ data: FraudDistPoint[] }>(
        "/api/v1/merchants/me/analytics/fraud_distribution"
      );
      setData(res.data);
    } catch {
      // handled
    } finally {
      setLoading(false);
    }
  }, [apiFetch]);

  useEffect(() => { fetchData(); }, [fetchData]);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Fraud Risk Distribution</CardTitle>
      </CardHeader>

      <div className="mt-4 h-48">
        {loading ? (
          <div className="flex h-full items-center justify-center">
            <Loader2 className="h-5 w-5 animate-spin text-indigo-600" />
          </div>
        ) : data.every((d) => d.count === 0) ? (
          <div className="flex h-full items-center justify-center">
            <p className="text-sm text-slate-400">No fraud scoring data yet</p>
          </div>
        ) : (
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data} margin={{ top: 5, right: 5, bottom: 5, left: 5 }}>
              <XAxis
                dataKey="range"
                tick={{ fontSize: 10, fill: "#94A3B8" }}
                tickLine={false}
                axisLine={false}
              />
              <YAxis
                tick={{ fontSize: 10, fill: "#94A3B8" }}
                tickLine={false}
                axisLine={false}
                width={35}
              />
              <Tooltip
                contentStyle={{
                  borderRadius: 8,
                  border: "1px solid #E2E8F0",
                  fontSize: 12,
                }}
                formatter={(value) => [value, "Transactions"]}
              />
              <Bar dataKey="count" radius={[4, 4, 0, 0]}>
                {data.map((entry, i) => (
                  <Cell key={i} fill={COLORS[entry.range] || "#94A3B8"} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>
    </Card>
  );
}
