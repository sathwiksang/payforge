"use client";

import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from "react";
import { useRouter } from "next/navigation";

function getApiBase(): string {
  if (typeof window !== "undefined") {
    const host = window.location.hostname;
    if (host === "payforge.sathwiksangeethamproject.dev") {
      return "https://payforge-api.sathwiksangeethamproject.dev";
    }
  }
  return process.env.NEXT_PUBLIC_API_URL || "http://localhost:3200";
}

interface User {
  id: string;
  email: string;
  role: string;
  merchant_id: string;
}

interface AuthContextType {
  user: User | null;
  token: string | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  apiFetch: <T>(path: string, options?: RequestInit) => Promise<T>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    const savedToken = localStorage.getItem("payforge_token");
    const savedUser = localStorage.getItem("payforge_user");
    if (savedToken && savedUser) {
      setToken(savedToken);
      setUser(JSON.parse(savedUser));
    }
    setLoading(false);
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const res = await fetch(`${getApiBase()}/api/v1/auth/sign_in`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ user: { email, password } }),
    });

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || "Login failed");
    }

    const jwt = res.headers.get("Authorization")?.replace("Bearer ", "") || "";
    const body = await res.json();

    setToken(jwt);
    setUser(body.user);
    localStorage.setItem("payforge_token", jwt);
    localStorage.setItem("payforge_user", JSON.stringify(body.user));
    router.push("/dashboard");
  }, [router]);

  const logout = useCallback(() => {
    setToken(null);
    setUser(null);
    localStorage.removeItem("payforge_token");
    localStorage.removeItem("payforge_user");
    router.push("/");
  }, [router]);

  const apiFetch = useCallback(async <T,>(path: string, options: RequestInit = {}): Promise<T> => {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      ...(options.headers as Record<string, string> || {}),
    };
    if (token) {
      headers["Authorization"] = `Bearer ${token}`;
    }

    const res = await fetch(`${getApiBase()}${path}`, { ...options, headers });

    if (res.status === 401) {
      logout();
      throw new Error("Session expired");
    }

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error?.message || body.error || "Request failed");
    }

    return res.json();
  }, [token, logout]);

  return (
    <AuthContext.Provider value={{ user, token, loading, login, logout, apiFetch }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
