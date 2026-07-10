"use client";

import { motion } from "framer-motion";
import { TrendingUp, TrendingDown } from "lucide-react";
import { Sparkline } from "./sparkline";
import { useAnimatedNumber } from "@/hooks/use-animated-number";

interface MetricCardProps {
  title: string;
  value: number;
  format: (n: number) => string;
  change?: number;
  sparklineData: number[];
  delay?: number;
}

export function MetricCard({ title, value, format, change, sparklineData, delay = 0 }: MetricCardProps) {
  const animatedValue = useAnimatedNumber(value);
  const isPositive = (change ?? 0) >= 0;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay, duration: 0.4, ease: [0.4, 0, 0.2, 1] }}
      className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm transition-shadow hover:shadow-md"
    >
      <p className="text-sm font-medium text-slate-500">{title}</p>

      <div className="mt-2 flex items-baseline gap-2">
        <span className="text-2xl font-bold text-slate-900 tabular-nums">
          {format(animatedValue)}
        </span>

        {change !== undefined && (
          <span
            className={`inline-flex items-center gap-0.5 text-xs font-medium ${
              isPositive ? "text-emerald-600" : "text-red-500"
            }`}
          >
            {isPositive ? <TrendingUp size={12} /> : <TrendingDown size={12} />}
            {Math.abs(change).toFixed(1)}%
          </span>
        )}
      </div>

      <div className="mt-4">
        <Sparkline
          data={sparklineData}
          color={isPositive ? "#10B981" : "#EF4444"}
        />
      </div>
    </motion.div>
  );
}
