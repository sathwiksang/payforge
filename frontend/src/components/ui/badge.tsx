import { cn } from "@/lib/utils";
import { type TransactionStatus, type FraudDecision, type FraudCasePriority } from "@/types";

const statusConfig: Record<string, { label: string; className: string }> = {
  pending: { label: "Pending", className: "bg-slate-100 text-slate-700" },
  initiated: { label: "Initiated", className: "bg-blue-50 text-blue-700" },
  authorized: { label: "Authorized", className: "bg-indigo-50 text-indigo-700" },
  fraud_cleared: { label: "Cleared", className: "bg-emerald-50 text-emerald-700" },
  captured: { label: "Captured", className: "bg-emerald-50 text-emerald-700" },
  settled: { label: "Settled", className: "bg-emerald-100 text-emerald-800" },
  failed: { label: "Failed", className: "bg-red-50 text-red-700" },
  refunded: { label: "Refunded", className: "bg-amber-50 text-amber-700" },
  partially_refunded: { label: "Partial Refund", className: "bg-amber-50 text-amber-700" },
  voided: { label: "Voided", className: "bg-slate-100 text-slate-600" },
  blocked: { label: "Blocked", className: "bg-red-100 text-red-800" },
};

const fraudConfig: Record<string, { label: string; className: string }> = {
  pass: { label: "Pass", className: "bg-emerald-50 text-emerald-700" },
  review: { label: "Review", className: "bg-amber-50 text-amber-700" },
  block: { label: "Block", className: "bg-red-50 text-red-700" },
};

const priorityConfig: Record<string, { label: string; className: string }> = {
  low: { label: "Low", className: "bg-slate-100 text-slate-600" },
  medium: { label: "Medium", className: "bg-blue-50 text-blue-700" },
  high: { label: "High", className: "bg-amber-50 text-amber-700" },
  critical: { label: "Critical", className: "bg-red-100 text-red-800" },
};

interface BadgeProps {
  children: React.ReactNode;
  className?: string;
  variant?: "default" | "outline";
}

export function Badge({ children, className, variant = "default" }: BadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
        variant === "outline" && "border border-current bg-transparent",
        className
      )}
    >
      {children}
    </span>
  );
}

export function StatusBadge({ status }: { status: TransactionStatus }) {
  const config = statusConfig[status] || { label: status, className: "bg-slate-100 text-slate-600" };
  return <Badge className={config.className}>{config.label}</Badge>;
}

export function FraudBadge({ decision }: { decision: FraudDecision }) {
  const config = fraudConfig[decision] || { label: decision, className: "bg-slate-100 text-slate-600" };
  return <Badge className={config.className}>{config.label}</Badge>;
}

export function PriorityBadge({ priority }: { priority: FraudCasePriority }) {
  const config = priorityConfig[priority] || { label: priority, className: "bg-slate-100 text-slate-600" };
  return <Badge className={config.className}>{config.label}</Badge>;
}
