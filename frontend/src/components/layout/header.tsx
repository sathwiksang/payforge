"use client";

import { useState, useRef, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Search,
  Bell,
  User,
  LogOut,
  Settings,
  ChevronDown,
  CreditCard,
  ShieldAlert,
  CheckCircle,
  X,
} from "lucide-react";
import { useAuth } from "@/lib/auth";
import { useNotifications } from "@/lib/notifications";
import { CommandPalette } from "./command-palette";
import { formatRelativeTime } from "@/lib/utils";
import Link from "next/link";

interface Notification {
  id: string;
  type: "payment" | "fraud" | "system";
  title: string;
  description: string;
  read: boolean;
  created_at: string;
}

export function Header() {
  const [commandOpen, setCommandOpen] = useState(false);
  const [userMenuOpen, setUserMenuOpen] = useState(false);
  const [notifOpen, setNotifOpen] = useState(false);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const { user, logout, apiFetch } = useAuth();
  const { notify } = useNotifications();
  const userMenuRef = useRef<HTMLDivElement>(null);
  const notifRef = useRef<HTMLDivElement>(null);

  // Fetch recent activity as notifications
  const fetchNotifications = useCallback(async () => {
    try {
      const res = await apiFetch<{
        data: { type: string; title: string; description: string; created_at: string }[];
      }>("/api/v1/merchants/me/analytics/recent_activity");
      setNotifications(
        res.data.map((item, i) => ({
          id: `notif_${i}`,
          type: item.type.includes("fraud") ? "fraud" : item.type.includes("payment") ? "payment" : "system",
          title: item.title,
          description: item.description,
          read: i > 2,
          created_at: item.created_at,
        }))
      );
    } catch {
      // Not critical — silently ignore
    }
  }, [apiFetch]);

  useEffect(() => {
    fetchNotifications();
    const interval = setInterval(fetchNotifications, 30000);
    return () => clearInterval(interval);
  }, [fetchNotifications]);

  // Close dropdowns when clicking outside
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (userMenuRef.current && !userMenuRef.current.contains(e.target as Node)) {
        setUserMenuOpen(false);
      }
      if (notifRef.current && !notifRef.current.contains(e.target as Node)) {
        setNotifOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const unreadCount = notifications.filter((n) => !n.read).length;

  function markAllRead() {
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    notify("info", "Notifications cleared");
  }

  function handleLogout() {
    setUserMenuOpen(false);
    notify("success", "Signed out", "You have been signed out successfully");
    setTimeout(() => logout(), 300);
  }

  const notifIcons: Record<string, typeof CreditCard> = {
    payment: CreditCard,
    fraud: ShieldAlert,
    system: CheckCircle,
  };

  return (
    <>
      <header className="sticky top-0 z-20 flex h-16 items-center justify-between border-b border-slate-200 bg-white/80 px-6 backdrop-blur-sm">
        {/* Search trigger */}
        <button
          onClick={() => setCommandOpen(true)}
          className="flex items-center gap-2.5 rounded-lg border border-slate-200 bg-slate-50 px-3.5 py-2 text-sm text-slate-400 transition-colors hover:border-slate-300 hover:text-slate-500"
        >
          <Search size={15} />
          <span>Search transactions, merchants...</span>
          <kbd className="ml-4 hidden rounded border border-slate-200 bg-white px-1.5 py-0.5 text-xs font-medium text-slate-400 sm:inline">
            ⌘K
          </kbd>
        </button>

        {/* Right side */}
        <div className="flex items-center gap-2">
          {/* Notifications */}
          <div className="relative" ref={notifRef}>
            <button
              onClick={() => setNotifOpen(!notifOpen)}
              className="relative rounded-lg p-2 text-slate-400 transition-colors hover:bg-slate-50 hover:text-slate-600"
            >
              <Bell size={18} />
              {unreadCount > 0 && (
                <span className="absolute right-1 top-1 flex h-4 w-4 items-center justify-center rounded-full bg-red-500 text-[10px] font-bold text-white">
                  {unreadCount > 9 ? "9+" : unreadCount}
                </span>
              )}
            </button>

            <AnimatePresence>
              {notifOpen && (
                <motion.div
                  initial={{ opacity: 0, y: 8, scale: 0.96 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: 8, scale: 0.96 }}
                  transition={{ duration: 0.15 }}
                  className="absolute right-0 top-full mt-2 w-96 rounded-xl border border-slate-200 bg-white shadow-xl overflow-hidden"
                >
                  <div className="flex items-center justify-between border-b border-slate-100 px-4 py-3">
                    <h3 className="text-sm font-semibold text-slate-900">Notifications</h3>
                    <div className="flex items-center gap-2">
                      {unreadCount > 0 && (
                        <button
                          onClick={markAllRead}
                          className="text-xs text-indigo-600 hover:text-indigo-700 font-medium"
                        >
                          Mark all read
                        </button>
                      )}
                      <button
                        onClick={() => setNotifOpen(false)}
                        className="text-slate-400 hover:text-slate-600"
                      >
                        <X size={14} />
                      </button>
                    </div>
                  </div>

                  <div className="max-h-80 overflow-y-auto">
                    {notifications.length === 0 ? (
                      <div className="py-8 text-center text-sm text-slate-400">
                        No notifications
                      </div>
                    ) : (
                      notifications.map((notif) => {
                        const Icon = notifIcons[notif.type] || CheckCircle;
                        return (
                          <div
                            key={notif.id}
                            className={`flex items-start gap-3 px-4 py-3 border-b border-slate-50 last:border-0 transition-colors ${
                              notif.read ? "opacity-60" : "bg-indigo-50/30"
                            }`}
                          >
                            <div
                              className={`rounded-lg p-1.5 mt-0.5 ${
                                notif.type === "fraud"
                                  ? "bg-amber-100 text-amber-600"
                                  : notif.type === "payment"
                                  ? "bg-emerald-100 text-emerald-600"
                                  : "bg-slate-100 text-slate-500"
                              }`}
                            >
                              <Icon size={12} />
                            </div>
                            <div className="flex-1 min-w-0">
                              <p className="text-sm font-medium text-slate-900 truncate">
                                {notif.title}
                              </p>
                              <p className="text-xs text-slate-500">{notif.description}</p>
                            </div>
                            <span className="text-[10px] text-slate-400 whitespace-nowrap mt-0.5">
                              {formatRelativeTime(notif.created_at)}
                            </span>
                          </div>
                        );
                      })
                    )}
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>

          {/* User menu */}
          <div className="relative" ref={userMenuRef}>
            <button
              onClick={() => setUserMenuOpen(!userMenuOpen)}
              className="flex items-center gap-2 rounded-lg px-2 py-1.5 text-sm text-slate-600 transition-colors hover:bg-slate-50"
            >
              <div className="flex h-8 w-8 items-center justify-center rounded-full bg-indigo-100 text-indigo-600">
                <User size={16} />
              </div>
              <div className="hidden sm:block text-left">
                <p className="text-sm font-medium text-slate-700 leading-none">
                  {user?.email?.split("@")[0] || "User"}
                </p>
                <p className="text-[11px] text-slate-400 capitalize">{user?.role || "admin"}</p>
              </div>
              <ChevronDown size={14} className="text-slate-400" />
            </button>

            <AnimatePresence>
              {userMenuOpen && (
                <motion.div
                  initial={{ opacity: 0, y: 8, scale: 0.96 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: 8, scale: 0.96 }}
                  transition={{ duration: 0.15 }}
                  className="absolute right-0 top-full mt-2 w-56 rounded-xl border border-slate-200 bg-white py-1 shadow-xl overflow-hidden"
                >
                  <div className="px-3 py-2.5 border-b border-slate-100">
                    <p className="text-sm font-medium text-slate-900">{user?.email || "admin@payforge.dev"}</p>
                    <p className="text-xs text-slate-500 capitalize">{user?.role || "admin"} account</p>
                  </div>

                  <div className="py-1">
                    <Link
                      href="/settings"
                      onClick={() => setUserMenuOpen(false)}
                      className="flex items-center gap-2.5 px-3 py-2 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
                    >
                      <Settings size={14} className="text-slate-400" />
                      Settings
                    </Link>
                  </div>

                  <div className="border-t border-slate-100 py-1">
                    <button
                      onClick={handleLogout}
                      className="flex w-full items-center gap-2.5 px-3 py-2 text-sm text-red-600 hover:bg-red-50 transition-colors"
                    >
                      <LogOut size={14} />
                      Sign out
                    </button>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>
      </header>

      <CommandPalette open={commandOpen} onClose={() => setCommandOpen(false)} />
    </>
  );
}
