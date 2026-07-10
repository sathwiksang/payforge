"use client";

import { useState, useCallback } from "react";
import type { Toast, ToastType } from "@/components/ui/toast";

let toastId = 0;

export function useToast() {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const addToast = useCallback((type: ToastType, title: string, description?: string) => {
    const id = String(++toastId);
    setToasts((prev) => [...prev, { id, type, title, description }]);

    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 5000);
  }, []);

  const dismiss = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  return {
    toasts,
    dismiss,
    success: (title: string, desc?: string) => addToast("success", title, desc),
    error: (title: string, desc?: string) => addToast("error", title, desc),
    warning: (title: string, desc?: string) => addToast("warning", title, desc),
    info: (title: string, desc?: string) => addToast("info", title, desc),
  };
}
