"use client";

import { useState, useEffect, useCallback } from "react";
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from "recharts";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { useAuth } from "@/lib/auth";
import { Loader2 } from "lucide-react";

interface PaymentMethodData {
  name: string;
  value: number;
}

const COLORS = ["#6366F1", "#8B5CF6", "#A78BFA", "#C4B5FD", "#DDD6FE"];

export function PaymentMethodsChart() {
  const { apiFetch } = useAuth();
  const [data, setData] = useState<PaymentMethodData[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    try {
      const res = await apiFetch<{ data: PaymentMethodData[] }>(
        "/api/v1/merchants/me/analytics/payment_methods"
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
        <CardTitle>Payment Methods</CardTitle>
      </CardHeader>

      <div className="mt-2 flex items-center gap-6">
        {loading ? (
          <div className="flex h-44 w-full items-center justify-center">
            <Loader2 className="h-5 w-5 animate-spin text-indigo-600" />
          </div>
        ) : data.length === 0 ? (
          <div className="flex h-44 w-full items-center justify-center">
            <p className="text-sm text-slate-400">No transaction data</p>
          </div>
        ) : (
          <>
            <div className="h-44 w-44 flex-shrink-0">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={data}
                    cx="50%"
                    cy="50%"
                    innerRadius={45}
                    outerRadius={70}
                    paddingAngle={3}
                    dataKey="value"
                    strokeWidth={0}
                  >
                    {data.map((_, i) => (
                      <Cell key={i} fill={COLORS[i % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{
                      borderRadius: 8,
                      border: "1px solid #E2E8F0",
                      fontSize: 12,
                    }}
                    formatter={(value) => [`${value}%`, "Share"]}
                  />
                </PieChart>
              </ResponsiveContainer>
            </div>

            <div className="space-y-2.5">
              {data.map((item, i) => (
                <div key={item.name} className="flex items-center gap-2.5">
                  <span
                    className="h-2.5 w-2.5 rounded-full"
                    style={{ backgroundColor: COLORS[i % COLORS.length] }}
                  />
                  <span className="text-sm text-slate-600">{item.name}</span>
                  <span className="text-sm font-medium text-slate-900 tabular-nums">
                    {item.value}%
                  </span>
                </div>
              ))}
            </div>
          </>
        )}
      </div>
    </Card>
  );
}
