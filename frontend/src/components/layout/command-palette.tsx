"use client";

import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Search, CreditCard, ShieldAlert, Building2, ArrowRight } from "lucide-react";
import { useRouter } from "next/navigation";

interface CommandPaletteProps {
  open: boolean;
  onClose: () => void;
}

const quickActions = [
  { name: "View Transactions", icon: CreditCard, href: "/transactions" },
  { name: "Fraud Cases", icon: ShieldAlert, href: "/fraud-cases" },
  { name: "Merchants", icon: Building2, href: "/merchants" },
];

export function CommandPalette({ open, onClose }: CommandPaletteProps) {
  const [query, setQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const router = useRouter();

  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        if (open) {
          onClose();
        } else {
          // Parent will handle opening via state
        }
      }
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [open, onClose]);

  useEffect(() => {
    if (open) {
      setTimeout(() => {
        if (inputRef.current) {
          inputRef.current.value = "";
          inputRef.current.focus();
        }
      }, 50);
    }
  }, [open]);

  const filtered = quickActions.filter((a) =>
    a.name.toLowerCase().includes(query.toLowerCase())
  );

  return (
    <AnimatePresence>
      {open && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 z-50 bg-black/20 backdrop-blur-sm"
          />

          {/* Dialog */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: -20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: -20 }}
            transition={{ type: "spring", stiffness: 400, damping: 30 }}
            className="fixed left-1/2 top-[20%] z-50 w-full max-w-lg -translate-x-1/2"
          >
            <div className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-2xl">
              {/* Search input */}
              <div className="flex items-center gap-3 border-b border-slate-200 px-4 py-3">
                <Search size={18} className="text-slate-400" />
                <input
                  ref={inputRef}
                  type="text"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="Search transactions, merchants, fraud cases..."
                  className="flex-1 bg-transparent text-sm text-slate-900 placeholder:text-slate-400 outline-none"
                />
                <kbd className="rounded border border-slate-200 bg-slate-50 px-1.5 py-0.5 text-xs text-slate-400">
                  ESC
                </kbd>
              </div>

              {/* Results */}
              <div className="max-h-72 overflow-y-auto p-2">
                {filtered.length === 0 ? (
                  <p className="py-8 text-center text-sm text-slate-400">No results found</p>
                ) : (
                  <div className="space-y-0.5">
                    <p className="px-2 py-1.5 text-xs font-medium text-slate-400 uppercase tracking-wider">
                      Quick Actions
                    </p>
                    {filtered.map((action) => (
                      <button
                        key={action.name}
                        onClick={() => {
                          router.push(action.href);
                          onClose();
                        }}
                        className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-slate-700 transition-colors hover:bg-slate-50"
                      >
                        <action.icon size={16} className="text-slate-400" />
                        <span className="flex-1 text-left">{action.name}</span>
                        <ArrowRight size={14} className="text-slate-300" />
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
