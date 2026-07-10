"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Brain, AlertTriangle, CheckCircle, ShieldAlert, Zap, RotateCcw } from "lucide-react";
import { cn } from "@/lib/utils";

interface Feature {
  name: string;
  label: string;
  contribution: number;
  description: string;
  value: string;
}

const SCENARIOS = [
  {
    id: "legit",
    label: "Legitimate Purchase",
    score: 0.03,
    decision: "pass" as const,
    color: "text-emerald-600",
    bgColor: "bg-emerald-50 border-emerald-200",
    transaction: { amount: "$42.50", merchant: "Coffee Shop", country: "US", card: "•••• 4242" },
    features: [
      { name: "velocity_1h", label: "Velocity (1h)", contribution: -0.02, description: "1 transaction in last hour", value: "1" },
      { name: "country_match", label: "Country Match", contribution: -0.15, description: "Card country matches IP", value: "Match" },
      { name: "amount", label: "Amount", contribution: -0.08, description: "Below average transaction", value: "$42.50" },
      { name: "merchant_history", label: "Merchant History", contribution: -0.12, description: "Previous purchases at this merchant", value: "5 prior" },
      { name: "device_fingerprint", label: "Device Trust", contribution: -0.05, description: "Known device", value: "Trusted" },
      { name: "time_of_day", label: "Time Pattern", contribution: +0.01, description: "Slightly unusual hour", value: "11 PM" },
    ],
  },
  {
    id: "suspicious",
    label: "Suspicious Activity",
    score: 0.72,
    decision: "review" as const,
    color: "text-amber-600",
    bgColor: "bg-amber-50 border-amber-200",
    transaction: { amount: "$899.99", merchant: "Electronics Store", country: "GB", card: "•••• 1234" },
    features: [
      { name: "velocity_1h", label: "Velocity (1h)", contribution: +0.22, description: "3 transactions in last hour", value: "3" },
      { name: "country_match", label: "Country Mismatch", contribution: +0.18, description: "Card country differs from IP", value: "US→GB" },
      { name: "amount", label: "High Amount", contribution: +0.15, description: "Amount above average", value: "$899.99" },
      { name: "merchant_history", label: "New Merchant", contribution: +0.08, description: "First purchase at merchant", value: "0 prior" },
      { name: "device_fingerprint", label: "New Device", contribution: +0.06, description: "Unknown device fingerprint", value: "New" },
      { name: "time_of_day", label: "Normal Hours", contribution: -0.03, description: "Business hours", value: "2 PM" },
    ],
  },
  {
    id: "fraud",
    label: "Likely Fraud",
    score: 0.96,
    decision: "block" as const,
    color: "text-red-600",
    bgColor: "bg-red-50 border-red-200",
    transaction: { amount: "$4,999.00", merchant: "Gift Cards Online", country: "NG", card: "•••• 9876" },
    features: [
      { name: "velocity_1h", label: "Velocity (1h)", contribution: +0.28, description: "8 transactions in last hour", value: "8" },
      { name: "country_match", label: "Country Mismatch", contribution: +0.25, description: "Card US, IP Nigeria", value: "US→NG" },
      { name: "amount", label: "Very High Amount", contribution: +0.18, description: "Near card limit", value: "$4,999" },
      { name: "merchant_history", label: "High-Risk Category", contribution: +0.14, description: "Gift cards — common fraud vector", value: "Gift Cards" },
      { name: "device_fingerprint", label: "VPN Detected", contribution: +0.10, description: "Anonymized connection", value: "VPN" },
      { name: "time_of_day", label: "Unusual Hour", contribution: +0.05, description: "3 AM in card's timezone", value: "3 AM" },
    ],
  },
];

const DECISION_STYLES = {
  pass: { color: "text-emerald-700", bg: "bg-emerald-100", icon: CheckCircle, label: "PASS" },
  review: { color: "text-amber-700", bg: "bg-amber-100", icon: AlertTriangle, label: "REVIEW" },
  block: { color: "text-red-700", bg: "bg-red-100", icon: ShieldAlert, label: "BLOCK" },
};

export function FraudScoringDemo() {
  const [activeScenario, setActiveScenario] = useState(0);
  const [isScoring, setIsScoring] = useState(false);
  const [showResults, setShowResults] = useState(true);
  const [animatedFeatures, setAnimatedFeatures] = useState<number>(6);

  const scenario = SCENARIOS[activeScenario];
  const decision = DECISION_STYLES[scenario.decision];
  const DecisionIcon = decision.icon;

  function runScoring(index: number) {
    setActiveScenario(index);
    setIsScoring(true);
    setShowResults(false);
    setAnimatedFeatures(0);

    // Animate features appearing one by one
    const featureCount = SCENARIOS[index].features.length;
    let i = 0;
    const interval = setInterval(() => {
      i++;
      setAnimatedFeatures(i);
      if (i >= featureCount) {
        clearInterval(interval);
        setTimeout(() => {
          setIsScoring(false);
          setShowResults(true);
        }, 400);
      }
    }, 200);
  }

  const maxContribution = Math.max(
    ...scenario.features.map((f) => Math.abs(f.contribution))
  );

  return (
    <div className="rounded-2xl border border-slate-200 bg-white overflow-hidden shadow-sm">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 bg-slate-50 border-b border-slate-200">
        <div className="flex items-center gap-2.5">
          <Brain size={16} className="text-purple-600" />
          <div>
            <h3 className="text-base font-bold text-slate-900">Fraud Scoring Engine</h3>
            <p className="text-xs text-slate-500 mt-0.5">Select a scenario to see real-time ML scoring with SHAP explanations</p>
          </div>
        </div>
        <button
          onClick={() => runScoring(activeScenario)}
          className="flex items-center gap-1.5 rounded-lg bg-purple-600 px-3.5 py-1.5 text-xs font-semibold text-white hover:bg-purple-700 transition-colors"
        >
          <RotateCcw size={12} />
          Re-score
        </button>
      </div>

      {/* Scenario Selector */}
      <div className="flex border-b border-slate-200">
        {SCENARIOS.map((s, i) => (
          <button
            key={s.id}
            onClick={() => runScoring(i)}
            className={cn(
              "flex-1 py-3 px-4 text-xs font-semibold transition-all border-b-2",
              i === activeScenario
                ? `${s.color} border-current bg-slate-50`
                : "text-slate-400 border-transparent hover:text-slate-600 hover:bg-slate-50/50"
            )}
          >
            {s.label}
          </button>
        ))}
      </div>

      <div className="p-6">
        {/* Transaction Details */}
        <div className="grid grid-cols-4 gap-3 mb-6">
          {Object.entries(scenario.transaction).map(([key, value]) => (
            <div key={key} className="rounded-lg bg-slate-50 border border-slate-100 px-3 py-2">
              <div className="text-[10px] uppercase tracking-wider text-slate-400 mb-0.5">
                {key.replace("_", " ")}
              </div>
              <div className="text-sm font-semibold text-slate-900">{value}</div>
            </div>
          ))}
        </div>

        {/* SHAP Waterfall */}
        <div className="mb-6">
          <div className="flex items-center gap-2 mb-3">
            <Zap size={12} className="text-purple-500" />
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              SHAP Feature Contributions
            </span>
          </div>

          <div className="space-y-2">
            {scenario.features.map((feature, i) => {
              const isVisible = i < animatedFeatures;
              const barWidth = (Math.abs(feature.contribution) / maxContribution) * 100;
              const isPositive = feature.contribution > 0;

              return (
                <motion.div
                  key={feature.name}
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: isVisible ? 1 : 0, x: isVisible ? 0 : -10 }}
                  transition={{ duration: 0.3 }}
                  className="flex items-center gap-3"
                >
                  <div className="w-28 flex-shrink-0">
                    <span className="text-xs font-medium text-slate-700">{feature.label}</span>
                  </div>

                  {/* Bar */}
                  <div className="flex-1 flex items-center">
                    <div className="relative h-6 flex-1 flex items-center">
                      {/* Center line */}
                      <div className="absolute left-1/2 top-0 bottom-0 w-px bg-slate-300" />

                      {isPositive ? (
                        <motion.div
                          initial={{ width: 0 }}
                          animate={{ width: isVisible ? `${barWidth / 2}%` : 0 }}
                          transition={{ duration: 0.5, delay: 0.1 }}
                          className="absolute left-1/2 h-5 rounded-r bg-red-400/80"
                        />
                      ) : (
                        <motion.div
                          initial={{ width: 0 }}
                          animate={{ width: isVisible ? `${barWidth / 2}%` : 0 }}
                          transition={{ duration: 0.5, delay: 0.1 }}
                          className="absolute right-1/2 h-5 rounded-l bg-emerald-400/80"
                          style={{ right: "50%" }}
                        />
                      )}
                    </div>
                  </div>

                  {/* Value */}
                  <div className="w-14 text-right flex-shrink-0">
                    <span
                      className={cn(
                        "text-xs font-bold font-mono",
                        isPositive ? "text-red-600" : "text-emerald-600"
                      )}
                    >
                      {isPositive ? "+" : ""}
                      {feature.contribution.toFixed(2)}
                    </span>
                  </div>

                  {/* Description */}
                  <div className="w-44 flex-shrink-0">
                    <span className="text-[11px] text-slate-500">{feature.description}</span>
                  </div>
                </motion.div>
              );
            })}
          </div>

          <div className="flex items-center justify-center gap-6 mt-3 pt-3 border-t border-slate-100">
            <div className="flex items-center gap-1.5 text-[10px] text-slate-400">
              <span className="h-2.5 w-5 rounded bg-emerald-400/80" /> Decreases risk
            </div>
            <div className="flex items-center gap-1.5 text-[10px] text-slate-400">
              <span className="h-2.5 w-5 rounded bg-red-400/80" /> Increases risk
            </div>
          </div>
        </div>

        {/* Score Result */}
        <AnimatePresence>
          {showResults && (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 10 }}
              className="rounded-xl bg-slate-900 p-5"
            >
              <div className="flex items-center justify-between">
                <div>
                  <span className="text-[10px] uppercase tracking-widest text-slate-500 font-semibold">
                    Risk Score
                  </span>
                  <div className="flex items-baseline gap-2 mt-1">
                    <span className={cn("text-3xl font-bold font-mono", scenario.color.replace("text-", "text-"))}>
                      {scenario.score.toFixed(2)}
                    </span>
                    <span className="text-xs text-slate-500">/ 1.00</span>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  {/* Score bar */}
                  <div className="w-32 h-2 rounded-full bg-slate-700 overflow-hidden">
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{ width: `${scenario.score * 100}%` }}
                      transition={{ duration: 0.8, ease: "easeOut" }}
                      className={cn(
                        "h-full rounded-full",
                        scenario.score < 0.3
                          ? "bg-emerald-500"
                          : scenario.score < 0.7
                          ? "bg-amber-500"
                          : "bg-red-500"
                      )}
                    />
                  </div>

                  <div className={cn("flex items-center gap-1.5 px-3 py-1.5 rounded-lg", decision.bg)}>
                    <DecisionIcon size={14} className={decision.color} />
                    <span className={cn("text-xs font-bold", decision.color)}>{decision.label}</span>
                  </div>
                </div>
              </div>

              <div className="mt-3 pt-3 border-t border-slate-700 flex items-center gap-4">
                <div className="flex items-center gap-1.5">
                  <span className="text-[10px] text-slate-500">Model:</span>
                  <code className="text-[11px] font-mono text-purple-400">lgbm_v1</code>
                </div>
                <div className="flex items-center gap-1.5">
                  <span className="text-[10px] text-slate-500">Latency:</span>
                  <code className="text-[11px] font-mono text-cyan-400">2.3ms</code>
                </div>
                <div className="flex items-center gap-1.5">
                  <span className="text-[10px] text-slate-500">Features:</span>
                  <code className="text-[11px] font-mono text-amber-400">6</code>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {isScoring && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="flex items-center justify-center gap-2 py-4"
          >
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
              className="h-4 w-4 rounded-full border-2 border-purple-500 border-t-transparent"
            />
            <span className="text-xs text-slate-500">Scoring transaction...</span>
          </motion.div>
        )}
      </div>
    </div>
  );
}
