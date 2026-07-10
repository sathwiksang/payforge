"use client";

import { AuthProvider } from "@/lib/auth";
import { NotificationsProvider } from "@/lib/notifications";
import { ToastContainer } from "@/components/ui/toast";
import { useNotifications } from "@/lib/notifications";
import type { ReactNode } from "react";

function ToastLayer() {
  const { toasts, dismiss } = useNotifications();
  return <ToastContainer toasts={toasts} onDismiss={dismiss} />;
}

export function Providers({ children }: { children: ReactNode }) {
  return (
    <AuthProvider>
      <NotificationsProvider>
        {children}
        <ToastLayer />
      </NotificationsProvider>
    </AuthProvider>
  );
}
