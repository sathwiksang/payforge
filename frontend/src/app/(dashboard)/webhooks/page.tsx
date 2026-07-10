"use client";

import { useState, useEffect, useCallback } from "react";
import { Webhook, CheckCircle, XCircle, Loader2 } from "lucide-react";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { formatDate } from "@/lib/utils";
import { useAuth } from "@/lib/auth";

interface ApiDelivery {
  id: string;
  event_type: string;
  event_id: string;
  status: string;
  response_code: number | null;
  error_message: string | null;
  attempts: number;
  delivered_at: string | null;
  created_at: string;
}

interface ApiResponse {
  data: ApiDelivery[];
  meta: { total_count: number; page: number; per_page: number; total_pages: number };
}

export default function WebhooksPage() {
  const { apiFetch } = useAuth();
  const [deliveries, setDeliveries] = useState<ApiDelivery[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const res = await apiFetch<ApiResponse>(`/api/v1/webhooks/deliveries?page=${page}&per_page=20`);
      setDeliveries(res.data);
      setTotalCount(res.meta.total_count);
      setTotalPages(res.meta.total_pages);
    } catch {
      // handled
    } finally {
      setLoading(false);
    }
  }, [apiFetch, page]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const successCount = deliveries.filter((d) => d.status === "delivered").length;
  const failedCount = deliveries.filter((d) => d.status === "failed").length;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Webhooks</h1>
          <p className="mt-1 text-sm text-slate-500">
            {totalCount} total deliveries
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Card>
          <p className="text-xs font-medium text-slate-400 uppercase">Total Deliveries</p>
          <p className="mt-1 text-2xl font-bold text-slate-900 tabular-nums">{totalCount}</p>
        </Card>
        <Card>
          <p className="text-xs font-medium text-slate-400 uppercase">Success (this page)</p>
          <p className="mt-1 text-2xl font-bold text-emerald-600 tabular-nums">{successCount}</p>
        </Card>
        <Card>
          <p className="text-xs font-medium text-slate-400 uppercase">Failed (this page)</p>
          <p className="mt-1 text-2xl font-bold text-red-600 tabular-nums">{failedCount}</p>
        </Card>
      </div>

      <Card padding="none">
        <CardHeader className="px-6 pt-6 pb-4">
          <CardTitle>Delivery Log</CardTitle>
        </CardHeader>

        {loading ? (
          <div className="flex items-center justify-center py-12">
            <Loader2 className="h-6 w-6 animate-spin text-indigo-600" />
          </div>
        ) : (
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-100 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                <th className="px-6 py-2.5">Event</th>
                <th className="px-4 py-2.5">Status</th>
                <th className="px-4 py-2.5">Response</th>
                <th className="px-4 py-2.5">Attempts</th>
                <th className="px-4 py-2.5 text-right pr-6">Time</th>
              </tr>
            </thead>
            <tbody>
              {deliveries.map((d) => (
                <tr key={d.id} className="border-b border-slate-50 text-sm">
                  <td className="px-6 py-2.5">
                    <Badge className="bg-slate-50 text-slate-600">{d.event_type}</Badge>
                  </td>
                  <td className="px-4 py-2.5">
                    <div className="flex items-center gap-1.5">
                      {d.status === "delivered" ? (
                        <CheckCircle size={14} className="text-emerald-500" />
                      ) : (
                        <XCircle size={14} className="text-red-500" />
                      )}
                      <span className={d.status === "delivered" ? "text-emerald-600" : "text-red-600"}>
                        {d.status}
                      </span>
                    </div>
                  </td>
                  <td className="px-4 py-2.5 tabular-nums text-slate-500 text-xs">
                    {d.response_code || "-"}
                  </td>
                  <td className="px-4 py-2.5 tabular-nums text-slate-500 text-xs">
                    {d.attempts}
                  </td>
                  <td className="px-4 py-2.5 text-right pr-6 text-xs text-slate-400">
                    {formatDate(d.created_at)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}

        {totalPages > 1 && (
          <div className="flex items-center justify-between border-t border-slate-100 px-6 py-3">
            <p className="text-xs text-slate-400">Page {page} of {totalPages}</p>
            <div className="flex gap-2">
              <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>Previous</Button>
              <Button variant="secondary" size="sm" disabled={page >= totalPages} onClick={() => setPage(page + 1)}>Next</Button>
            </div>
          </div>
        )}
      </Card>
    </div>
  );
}
