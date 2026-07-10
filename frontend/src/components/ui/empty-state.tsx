import { cn } from "@/lib/utils";
import { InboxIcon } from "lucide-react";

interface EmptyStateProps {
  icon?: React.ReactNode;
  title: string;
  description?: string;
  action?: React.ReactNode;
  className?: string;
}

export function EmptyState({ icon, title, description, action, className }: EmptyStateProps) {
  return (
    <div className={cn("flex flex-col items-center justify-center py-16 text-center", className)}>
      <div className="rounded-full bg-slate-100 p-4 text-slate-400">
        {icon || <InboxIcon size={32} />}
      </div>
      <h3 className="mt-4 text-base font-semibold text-slate-900">{title}</h3>
      {description && (
        <p className="mt-1.5 max-w-sm text-sm text-slate-500">{description}</p>
      )}
      {action && <div className="mt-6">{action}</div>}
    </div>
  );
}
