"use client";

import { useState, useEffect, useCallback } from "react";
import { CreditCard, ShieldAlert, CheckCircle, AlertTriangle, XCircle, Loader2 } from "lucide-react";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { cn, formatRelativeTime } from "@/lib/utils";
import { useAuth } from "@/lib/auth";

interface ActivityItem {
  type: string;
  title: string;
  description: string;
  created_at: string;
}

const iconConfig: Record<string, { icon: typeof CreditCard; className: string }> = {
  payment_captured: { icon: CreditCard, className: "bg-emerald-50 text-emerald-600" },
  refund: { icon: CreditCard, className: "bg-blue-50 text-blue-600" },
  fraud_blocked: { icon: ShieldAlert, className: "bg-red-50 text-red-600" },
  fraud_case: { icon: ShieldAlert, className: "bg-amber-50 text-amber-600" },
  settlement: { icon: CheckCircle, className: "bg-indigo-50 text-indigo-600" },
  payment_failed: { icon: XCircle, className: "bg-red-50 text-red-600" },
  transaction: { icon: AlertTriangle, className: "bg-slate-50 text-slate-600" },
};

export function RecentActivity() {
  const { apiFetch } = useAuth();
  const [activities, setActivities] = useState<ActivityItem[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchActivity = useCallback(async () => {
    try {
      const res = await apiFetch<{ data: ActivityItem[] }>(
        "/api/v1/merchants/me/analytics/recent_activity"
      );
      setActivities(res.data);
    } catch {
      // handled
    } finally {
      setLoading(false);
    }
  }, [apiFetch]);

  useEffect(() => { fetchActivity(); }, [fetchActivity]);

  return (
    <Card padding="none">
      <CardHeader className="px-6 pt-6 pb-4">
        <CardTitle>Recent Activity</CardTitle>
      </CardHeader>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-5 w-5 animate-spin text-indigo-600" />
        </div>
      ) : activities.length === 0 ? (
        <p className="px-6 pb-6 text-sm text-slate-400 text-center">No recent activity</p>
      ) : (
        <div className="divide-y divide-slate-50">
          {activities.map((activity, i) => {
            const cfg = iconConfig[activity.type] || iconConfig.transaction;
            const Icon = cfg.icon;
            return (
              <div key={i} className="flex items-start gap-3 px-6 py-3">
                <div className={cn("rounded-lg p-2", cfg.className)}>
                  <Icon size={14} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-slate-900">{activity.title}</p>
                  <p className="text-xs text-slate-500">{activity.description}</p>
                </div>
                <span className="text-xs text-slate-400 whitespace-nowrap">
                  {formatRelativeTime(activity.created_at)}
                </span>
              </div>
            );
          })}
        </div>
      )}
    </Card>
  );
}
