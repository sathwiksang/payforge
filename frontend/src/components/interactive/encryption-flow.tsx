"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Lock, Unlock, Eye, EyeOff, Search, ArrowRight, Shield } from "lucide-react";
import { cn } from "@/lib/utils";

const LAYERS = [
  {
    id: "plaintext",
    label: "Plaintext",
    icon: Unlock,
    color: "text-red-600",
    bgColor: "bg-red-50 border-red-200",
    data: {
      email: "alice@example.com",
      card_number: "4242424242424242",
      webhook_url: "https://merchant.com/hooks",
    },
  },
  {
    id: "lockbox",
    label: "Lockbox Encryption",
    icon: Lock,
    color: "text-indigo-600",
    bgColor: "bg-indigo-50 border-indigo-200",
    data: {
      email_ciphertext: "gXk9a2F...mNz4=",
      card_number_ciphertext: "pQr8bW...hJk7=",
      webhook_url_ciphertext: "vLm3cN...tYp2=",
    },
  },
  {
    id: "blind_index",
    label: "Blind Index",
    icon: Search,
    color: "text-emerald-600",
    bgColor: "bg-emerald-50 border-emerald-200",
    data: {
      email_bidx: "a1b2c3d4e5f6...",
      card_bidx: "f7g8h9i0j1k2...",
      webhook_bidx: "(not indexed)",
    },
  },
  {
    id: "stored",
    label: "Stored in PostgreSQL",
    icon: Shield,
    color: "text-purple-600",
    bgColor: "bg-purple-50 border-purple-200",
    data: {
      email_ciphertext: "gXk9a2F...mNz4=",
      email_bidx: "a1b2c3d4e5f6...",
      card_number_ciphertext: "pQr8bW...hJk7=",
    },
  },
];

export function EncryptionFlow() {
  const [activeLayer, setActiveLayer] = useState(0);
  const [isAnimating, setIsAnimating] = useState(false);
  const [showPlaintext, setShowPlaintext] = useState(true);

  function playAnimation() {
    setActiveLayer(0);
    setIsAnimating(true);
    setShowPlaintext(true);
    let current = 0;
    const interval = setInterval(() => {
      current++;
      if (current >= LAYERS.length) {
        clearInterval(interval);
        setIsAnimating(false);
        return;
      }
      if (current === 1) setShowPlaintext(false);
      setActiveLayer(current);
    }, 1200);
  }

  const layer = LAYERS[activeLayer];
  const LayerIcon = layer.icon;

  return (
    <div className="rounded-2xl border border-slate-200 bg-white overflow-hidden shadow-sm">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 bg-slate-50 border-b border-slate-200">
        <div className="flex items-center gap-2.5">
          <Lock size={16} className="text-indigo-600" />
          <div>
            <h3 className="text-base font-bold text-slate-900">Encryption Pipeline</h3>
            <p className="text-xs text-slate-500 mt-0.5">See how sensitive data is encrypted before storage</p>
          </div>
        </div>
        <button
          onClick={playAnimation}
          disabled={isAnimating}
          className="rounded-lg bg-indigo-600 px-3.5 py-1.5 text-xs font-semibold text-white hover:bg-indigo-700 disabled:opacity-50 transition-colors"
        >
          {isAnimating ? "Encrypting..." : "Play Encryption"}
        </button>
      </div>

      {/* Steps */}
      <div className="flex items-center gap-1 px-6 py-4 overflow-x-auto">
        {LAYERS.map((l, i) => (
          <div key={l.id} className="flex items-center flex-shrink-0">
            <motion.button
              onClick={() => { setActiveLayer(i); setIsAnimating(false); setShowPlaintext(i === 0); }}
              whileHover={{ scale: 1.03 }}
              whileTap={{ scale: 0.97 }}
              className={cn(
                "relative rounded-xl border-2 px-4 py-2.5 min-w-[130px] transition-all duration-300",
                i === activeLayer
                  ? `${l.bgColor} shadow-md`
                  : i < activeLayer
                  ? `${l.bgColor} opacity-50`
                  : "bg-slate-50 border-slate-200 opacity-40"
              )}
            >
              <div className="flex items-center gap-2">
                <l.icon size={13} className={i <= activeLayer ? l.color : "text-slate-400"} />
                <span className={cn("text-xs font-bold", i <= activeLayer ? "text-slate-900" : "text-slate-400")}>
                  {l.label}
                </span>
              </div>
            </motion.button>
            {i < LAYERS.length - 1 && (
              <div className="flex-shrink-0 mx-1">
                <ArrowRight size={13} className={i < activeLayer ? "text-indigo-500" : "text-slate-300"} />
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Data Display */}
      <div className="px-6 pb-6">
        <motion.div
          key={activeLayer}
          initial={{ opacity: 0, y: 5 }}
          animate={{ opacity: 1, y: 0 }}
          className="rounded-xl bg-slate-900 p-5"
        >
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <LayerIcon size={14} className={activeLayer === 0 ? "text-red-400" : "text-emerald-400"} />
              <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                {layer.label}
              </span>
            </div>
            <button
              onClick={() => setShowPlaintext(!showPlaintext)}
              className="flex items-center gap-1 text-[10px] text-slate-500 hover:text-slate-300 transition-colors"
            >
              {showPlaintext ? <Eye size={10} /> : <EyeOff size={10} />}
              {showPlaintext ? "Visible" : "Hidden"}
            </button>
          </div>

          <div className="space-y-2">
            {Object.entries(layer.data).map(([key, value], i) => (
              <motion.div
                key={key}
                initial={{ opacity: 0, x: -5 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: i * 0.1 }}
                className="flex items-center gap-2"
              >
                <code className="text-xs font-mono text-slate-500 min-w-[180px]">{key}:</code>
                <code className={cn(
                  "text-xs font-mono",
                  activeLayer === 0 ? "text-red-400" : "text-emerald-300"
                )}>
                  {showPlaintext || activeLayer === 0 ? value : "••••••••••••"}
                </code>
              </motion.div>
            ))}
          </div>

          {activeLayer > 0 && (
            <div className="mt-4 pt-3 border-t border-slate-700">
              <div className="flex items-center gap-4 text-[10px]">
                <span className="text-slate-500">Algorithm:</span>
                <code className="text-cyan-400 font-mono">
                  {activeLayer === 1 ? "AES-256-GCM" : activeLayer === 2 ? "HMAC-SHA256" : "PostgreSQL + Lockbox"}
                </code>
                <span className="text-slate-500">Library:</span>
                <code className="text-amber-400 font-mono">
                  {activeLayer === 1 ? "Lockbox" : activeLayer === 2 ? "BlindIndex" : "ActiveRecord"}
                </code>
              </div>
            </div>
          )}
        </motion.div>
      </div>
    </div>
  );
}
