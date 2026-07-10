"use client";

import { useState, useRef, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ArrowRight, RotateCcw, CheckCircle, XCircle, ShieldAlert, Clock, Banknote } from "lucide-react";
import { cn } from "@/lib/utils";

interface FlowState {
  id: string;
  label: string;
  description: string;
  icon: typeof CheckCircle;
  color: string;
  bgColor: string;
  events: string[];
  ledger?: string;
}

const STATES: FlowState[] = [
  {
    id: "pending",
    label: "Pending",
    description: "Transaction created, queued for processing",
    icon: Clock,
    color: "text-slate-500",
    bgColor: "bg-slate-100 border-slate-300",
    events: ["PaymentInitiated"],
  },
  {
    id: "authorized",
    label: "Authorized",
    description: "Card network approved the charge",
    icon: CheckCircle,
    color: "text-blue-600",
    bgColor: "bg-blue-50 border-blue-300",
    events: ["PaymentAuthorized"],
  },
  {
    id: "fraud_cleared",
    label: "Fraud Cleared",
    description: "ML model scored & passed the transaction",
    icon: ShieldAlert,
    color: "text-purple-600",
    bgColor: "bg-purple-50 border-purple-300",
    events: ["FraudCheckPassed"],
  },
  {
    id: "captured",
    label: "Captured",
    description: "Funds secured, merchant credited",
    icon: Banknote,
    color: "text-emerald-600",
    bgColor: "bg-emerald-50 border-emerald-300",
    events: ["PaymentCaptured"],
    ledger: "Debit merchant_receivable $50.00 / Credit payment_processing $50.00",
  },
  {
    id: "settled",
    label: "Settled",
    description: "Funds transferred to merchant account",
    icon: CheckCircle,
    color: "text-emerald-700",
    bgColor: "bg-emerald-100 border-emerald-400",
    events: ["PaymentSettled"],
    ledger: "Debit merchant_payout $48.25 / Credit merchant_receivable $48.25",
  },
];

const FAILURE_STATES: FlowState[] = [
  {
    id: "failed",
    label: "Failed",
    description: "Authorization declined by card network",
    icon: XCircle,
    color: "text-red-600",
    bgColor: "bg-red-50 border-red-300",
    events: ["AuthorizationFailed"],
  },
  {
    id: "blocked",
    label: "Blocked",
    description: "Fraud engine blocked the transaction",
    icon: ShieldAlert,
    color: "text-red-600",
    bgColor: "bg-red-50 border-red-300",
    events: ["FraudCheckBlocked"],
  },
  {
    id: "refunded",
    label: "Refunded",
    description: "Full refund issued to cardholder",
    icon: RotateCcw,
    color: "text-orange-600",
    bgColor: "bg-orange-50 border-orange-300",
    events: ["PaymentRefunded"],
    ledger: "Reverse all capture entries",
  },
];

export function PaymentFlow() {
  const [activeStep, setActiveStep] = useState(0);
  const [showFailures, setShowFailures] = useState(false);
  const [isPlaying, setIsPlaying] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  const stepRefs = useRef<(HTMLDivElement | null)[]>([]);

  const scrollToStep = useCallback((step: number) => {
    const container = scrollRef.current;
    const el = stepRefs.current[step];
    if (!container || !el) return;

    const containerRect = container.getBoundingClientRect();
    const elRect = el.getBoundingClientRect();
    const offset = elRect.left - containerRect.left - (containerRect.width / 2) + (elRect.width / 2);
    container.scrollBy({ left: offset, behavior: "smooth" });
  }, []);

  useEffect(() => {
    scrollToStep(activeStep);
  }, [activeStep, scrollToStep]);

  function playAnimation() {
    // Scroll back to start first
    if (scrollRef.current) {
      scrollRef.current.scrollTo({ left: 0, behavior: "smooth" });
    }
    setActiveStep(0);
    setIsPlaying(true);
    let step = 0;
    const interval = setInterval(() => {
      step++;
      if (step >= STATES.length) {
        clearInterval(interval);
        setIsPlaying(false);
        return;
      }
      setActiveStep(step);
    }, 1000);
  }

  const currentState = STATES[activeStep];

  return (
    <div className="rounded-2xl border border-slate-200 bg-white overflow-hidden shadow-sm">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 bg-slate-50 border-b border-slate-200">
        <div>
          <h3 className="text-base font-bold text-slate-900">Payment Lifecycle</h3>
          <p className="text-xs text-slate-500 mt-0.5">Click states to explore, or play the animation</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowFailures(!showFailures)}
            className={cn(
              "rounded-lg px-3 py-1.5 text-xs font-medium transition-all",
              showFailures
                ? "bg-red-100 text-red-700 border border-red-200"
                : "bg-slate-100 text-slate-600 border border-slate-200 hover:bg-slate-200"
            )}
          >
            {showFailures ? "Hide" : "Show"} Failures
          </button>
          <button
            onClick={playAnimation}
            disabled={isPlaying}
            className="rounded-lg bg-indigo-600 px-3.5 py-1.5 text-xs font-semibold text-white hover:bg-indigo-700 disabled:opacity-50 transition-colors"
          >
            {isPlaying ? "Playing..." : "Play Flow"}
          </button>
        </div>
      </div>

      {/* Flow visualization */}
      <div className="p-6">
        {/* Happy path */}
        <div ref={scrollRef} className="flex items-center gap-1 overflow-x-auto pb-4 scroll-smooth">
          {STATES.map((state, i) => (
            <div key={state.id} ref={(el) => { stepRefs.current[i] = el; }} className="flex items-center flex-shrink-0">
              <motion.button
                onClick={() => { setActiveStep(i); setIsPlaying(false); }}
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className={cn(
                  "relative rounded-xl border-2 px-4 py-3 min-w-[120px] transition-all duration-300",
                  i === activeStep
                    ? `${state.bgColor} shadow-lg`
                    : i < activeStep
                    ? `${state.bgColor} opacity-60`
                    : "bg-slate-50 border-slate-200 opacity-40"
                )}
              >
                <div className="flex items-center gap-2 mb-1">
                  <state.icon size={14} className={i <= activeStep ? state.color : "text-slate-400"} />
                  <span className={cn("text-xs font-bold", i <= activeStep ? "text-slate-900" : "text-slate-400")}>
                    {state.label}
                  </span>
                </div>
                <p className="text-[10px] text-slate-500 text-left leading-snug">
                  {state.description}
                </p>
                {i === activeStep && (
                  <motion.div
                    layoutId="active-state"
                    className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-2 h-2 rounded-full bg-indigo-600"
                  />
                )}
              </motion.button>
              {i < STATES.length - 1 && (
                <div className="flex-shrink-0 mx-1">
                  <motion.div
                    animate={{ opacity: i < activeStep ? 1 : 0.3 }}
                  >
                    <ArrowRight
                      size={14}
                      className={i < activeStep ? "text-indigo-500" : "text-slate-300"}
                    />
                  </motion.div>
                </div>
              )}
            </div>
          ))}
        </div>

        {/* Failure states */}
        <AnimatePresence>
          {showFailures && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: "auto", opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              className="overflow-hidden"
            >
              <div className="pt-4 border-t border-slate-200 mt-4">
                <p className="text-xs font-semibold text-red-500 uppercase tracking-wider mb-3">Alternative Outcomes</p>
                <div className="flex gap-3">
                  {FAILURE_STATES.map((state) => (
                    <div
                      key={state.id}
                      className={`rounded-xl border-2 ${state.bgColor} px-4 py-3 min-w-[140px]`}
                    >
                      <div className="flex items-center gap-2 mb-1">
                        <state.icon size={14} className={state.color} />
                        <span className="text-xs font-bold text-slate-900">{state.label}</span>
                      </div>
                      <p className="text-[10px] text-slate-500 leading-snug">{state.description}</p>
                    </div>
                  ))}
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Event details panel */}
        <motion.div
          key={activeStep}
          initial={{ opacity: 0, y: 5 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-6 rounded-xl bg-slate-900 p-4"
        >
          <div className="flex items-center gap-2 mb-2">
            <span className="text-[10px] uppercase tracking-widest text-indigo-400 font-semibold">
              Domain Events
            </span>
            <span className="text-[10px] text-slate-500">Step {activeStep + 1} of {STATES.length}</span>
          </div>
          <div className="space-y-1.5">
            {currentState.events.map((event) => (
              <div key={event} className="flex items-center gap-2">
                <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
                <code className="text-xs font-mono text-emerald-300">
                  Payments::Events::{event}
                </code>
              </div>
            ))}
            {currentState.ledger && (
              <div className="mt-2 pt-2 border-t border-slate-700">
                <span className="text-[10px] uppercase tracking-widest text-amber-400 font-semibold">
                  Ledger Entry
                </span>
                <code className="block text-xs font-mono text-amber-200 mt-1">
                  {currentState.ledger}
                </code>
              </div>
            )}
          </div>
        </motion.div>
      </div>
    </div>
  );
}
