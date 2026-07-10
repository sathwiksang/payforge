"use client";

import { createContext, useContext, useState, useCallback, useEffect, type ReactNode } from "react";
import type { Toast, ToastType } from "@/components/ui/toast";

interface NotificationsContextType {
  toasts: Toast[];
  notify: (type: ToastType, title: string, description?: string) => void;
  dismiss: (id: string) => void;
  clearAll: () => void;
}

const NotificationsContext = createContext<NotificationsContextType | null>(null);

export function NotificationsProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const dismiss = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const notify = useCallback((type: ToastType, title: string, description?: string) => {
    const id = `toast_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
    setToasts((prev) => [...prev, { id, type, title, description }]);
    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 5000);
  }, []);

  const clearAll = useCallback(() => {
    setToasts([]);
  }, []);

  return (
    <NotificationsContext.Provider value={{ toasts, notify, dismiss, clearAll }}>
      {children}
    </NotificationsContext.Provider>
  );
}

export function useNotifications() {
  const ctx = useContext(NotificationsContext);
  if (!ctx) throw new Error("useNotifications must be used within NotificationsProvider");
  return ctx;
}
