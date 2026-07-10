"use client";

import { motion } from "framer-motion";
import { useMemo } from "react";
import type { ShapFeature } from "@/types";

interface ShapWaterfallProps {
  baseValue: number;
  prediction: number;
  features: ShapFeature[];
}

export function ShapWaterfall({ baseValue, prediction, features }: ShapWaterfallProps) {
  const sortedFeatures = useMemo(
    () => [...features].sort((a, b) => Math.abs(b.shap_value) - Math.abs(a.shap_value)).slice(0, 8),
    [features]
  );

  const bars = useMemo(() => {
    return sortedFeatures.reduce<Array<ShapFeature & { start: number; end: number }>>((acc, f) => {
      const prev = acc.length > 0 ? acc[acc.length - 1].end : baseValue;
      acc.push({ ...f, start: prev, end: prev + f.shap_value });
      return acc;
    }, []);
  }, [sortedFeatures, baseValue]);

  const maxVal = Math.max(
    ...bars.map((b) => Math.max(Math.abs(b.start), Math.abs(b.end))),
    Math.abs(prediction),
    0.01
  );

  const scale = (v: number) => (v / maxVal) * 100;

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between text-sm">
        <span className="text-slate-500">
          Base risk: <span className="font-mono">{(baseValue * 100).toFixed(1)}%</span>
        </span>
        <span className="font-semibold text-slate-900">
          Final: <span className="font-mono">{(prediction * 100).toFixed(1)}%</span>
        </span>
      </div>

      <div className="space-y-2">
        {bars.map((bar, i) => (
          <motion.div
            key={bar.feature}
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: i * 0.06 }}
            className="flex items-center gap-3"
          >
            <span className="w-32 text-xs text-slate-600 truncate font-mono">
              {bar.feature}
            </span>

            <div className="flex-1 h-5 relative bg-slate-50 rounded overflow-hidden">
              <motion.div
                initial={{ width: 0 }}
                animate={{
                  width: `${Math.abs(scale(bar.end) - scale(bar.start))}%`,
                }}
                style={{
                  marginLeft: `${scale(Math.min(bar.start, bar.end))}%`,
                }}
                transition={{
                  type: "spring",
                  stiffness: 200,
                  damping: 25,
                  delay: i * 0.08,
                }}
                className={`absolute h-full rounded ${
                  bar.shap_value > 0 ? "bg-red-400" : "bg-emerald-400"
                }`}
              />
            </div>

            <span
              className={`w-16 text-xs font-mono text-right ${
                bar.shap_value > 0 ? "text-red-600" : "text-emerald-600"
              }`}
            >
              {bar.shap_value > 0 ? "+" : ""}
              {(bar.shap_value * 100).toFixed(2)}%
            </span>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
