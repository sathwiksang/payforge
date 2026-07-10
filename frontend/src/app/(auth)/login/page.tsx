"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { motion } from "framer-motion";
import { Zap, Eye, EyeOff, ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useAuth } from "@/lib/auth";

export default function LoginPage() {
  const [showPassword, setShowPassword] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const { login, user, loading } = useAuth();
  const router = useRouter();

  // Redirect to dashboard if already logged in
  useEffect(() => {
    if (!loading && user) {
      router.push("/dashboard");
    }
  }, [user, loading, router]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setSubmitting(true);
    try {
      await login(email, password);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setSubmitting(false);
    }
  }

  // Show nothing while checking auth
  if (loading || user) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-50">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-indigo-600 border-t-transparent" />
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-50">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-sm px-4"
      >
        <div className="flex items-center justify-center gap-2.5 mb-8">
          <Link href="/" className="flex items-center gap-2.5 group">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-600 group-hover:bg-indigo-700 transition-colors">
              <Zap size={22} className="text-white" />
            </div>
            <span className="text-2xl font-bold text-slate-900 tracking-tight">PayForge</span>
          </Link>
        </div>

        <div className="rounded-xl border border-slate-200 bg-white p-8 shadow-sm">
          <h1 className="text-xl font-bold text-slate-900 text-center">Sign in</h1>
          <p className="mt-1.5 text-sm text-slate-500 text-center">Welcome back to your dashboard</p>

          {error && (
            <div className="mt-4 rounded-lg bg-red-50 border border-red-200 p-3 text-sm text-red-700">
              {error}
            </div>
          )}

          <form className="mt-6 space-y-4" onSubmit={handleSubmit}>
            <Input
              id="email"
              label="Email"
              type="email"
              placeholder="you@company.com"
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />

            <div className="relative">
              <Input
                id="password"
                label="Password"
                type={showPassword ? "text" : "password"}
                placeholder="Enter your password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-[34px] text-slate-400 hover:text-slate-600"
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>

            <Button type="submit" className="w-full" size="lg" disabled={submitting}>
              {submitting ? "Signing in..." : "Sign in"}
            </Button>
          </form>

          <div className="mt-4 rounded-lg bg-slate-50 border border-slate-200 p-3">
            <p className="text-xs text-slate-500 font-medium mb-1">Demo credentials:</p>
            <p className="text-xs text-slate-600 font-mono">admin@payforge.dev / PayForge2026Secure</p>
          </div>
        </div>

        <div className="mt-4 text-center">
          <Link
            href="/"
            className="inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-700 transition-colors"
          >
            <ArrowLeft size={14} />
            Back to home
          </Link>
        </div>
      </motion.div>
    </div>
  );
}
