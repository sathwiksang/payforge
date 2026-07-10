"use client";

import { motion } from "framer-motion";
import { CheckCircle, Clock, XCircle } from "lucide-react";
import { cn } from "@/lib/utils";

interface TimelineStep {
  label: string;
  time: string;
  status: "completed" | "current" | "pending" | "failed";
  icon?: React.ReactNode;
}

interface LifecycleTimelineProps {
  steps: TimelineStep[];
}

const statusStyles = {
  completed: "bg-emerald-500 text-white",
  current: "bg-indigo-500 text-white ring-4 ring-indigo-100",
  pending: "bg-slate-200 text-slate-400",
  failed: "bg-red-500 text-white",
};

const lineStyles = {
  completed: "bg-emerald-500",
  current: "bg-indigo-300",
  pending: "bg-slate-200",
  failed: "bg-red-300",
};

export function LifecycleTimeline({ steps }: LifecycleTimelineProps) {
  return (
    <div className="flex items-start justify-between">
      {steps.map((step, i) => (
        <div key={i} className="flex flex-1 items-start">
          <div className="flex flex-col items-center">
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ delay: i * 0.1, type: "spring", stiffness: 300 }}
              className={cn(
                "flex h-8 w-8 items-center justify-center rounded-full",
                statusStyles[step.status]
              )}
            >
              {step.status === "completed" && <CheckCircle size={16} />}
              {step.status === "current" && <Clock size={16} />}
              {step.status === "failed" && <XCircle size={16} />}
              {step.status === "pending" && <Clock size={16} />}
            </motion.div>
            <p className="mt-2 text-xs font-medium text-slate-700">{step.label}</p>
            <p className="mt-0.5 text-xs text-slate-400 font-mono">{step.time}</p>
          </div>
          {i < steps.length - 1 && (
            <div className="mt-3.5 flex-1 px-2">
              <motion.div
                initial={{ scaleX: 0 }}
                animate={{ scaleX: 1 }}
                transition={{ delay: i * 0.1 + 0.05, duration: 0.3 }}
                className={cn("h-0.5 w-full origin-left", lineStyles[step.status])}
              />
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
